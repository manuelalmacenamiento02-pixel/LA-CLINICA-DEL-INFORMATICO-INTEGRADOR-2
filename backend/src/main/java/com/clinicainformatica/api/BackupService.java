package com.clinicainformatica.api;

import com.zaxxer.hikari.HikariDataSource;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.charset.StandardCharsets;
import java.net.URI;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.file.StandardOpenOption;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import javax.sql.DataSource;
import org.springframework.beans.factory.annotation.Value;
import org.flywaydb.core.Flyway;
import org.springframework.core.io.FileSystemResource;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.jdbc.core.JdbcTemplate;

@Service
public class BackupService {
    private static final long ADVISORY_LOCK_ID = 6_742_110_281L;
    private static final long PROCESS_TIMEOUT_MINUTES = 10;
    private static final System.Logger LOGGER = System.getLogger(BackupService.class.getName());

    private final JdbcTemplate jdbc;
    private final DataSource dataSource;
    private final SprintSixService sprintSixService;
    private final Path backupDirectory;
    private final String pgDumpExecutable;
    private final String pgRestoreExecutable;
    private final BackupMaintenanceGate maintenanceGate;
    private final Flyway flyway;

    public BackupService(JdbcTemplate jdbc, DataSource dataSource, SprintSixService sprintSixService,
        @Value("${clinica.backup.directory:${user.home}/clinica-backups}") String backupDirectory,
        @Value("${clinica.backup.pg-dump:pg_dump}") String pgDumpExecutable,
        @Value("${clinica.backup.pg-restore:pg_restore}") String pgRestoreExecutable,
        BackupMaintenanceGate maintenanceGate, Flyway flyway) {
        this.jdbc = jdbc;
        this.dataSource = dataSource;
        this.sprintSixService = sprintSixService;
        this.backupDirectory = Path.of(backupDirectory).toAbsolutePath().normalize();
        this.pgDumpExecutable = pgDumpExecutable;
        this.pgRestoreExecutable = pgRestoreExecutable;
        this.maintenanceGate = maintenanceGate;
        this.flyway = flyway;
    }

    public Map<String, Object> create(UUID requesterId) {
        try (Connection connection = dataSource.getConnection()) {
            if (!acquireLock(connection)) {
                throw new ApiException(HttpStatus.CONFLICT, "backup-in-progress",
                    "Ya hay un respaldo en ejecución.");
            }
            try {
                return createWhileLocked(requesterId);
            } finally {
                releaseLock(connection);
            }
        } catch (SQLException e) {
            LOGGER.log(System.Logger.Level.ERROR, "No se pudo obtener el bloqueo para respaldos.", e);
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "backup-unavailable",
                "No se pudo iniciar el respaldo porque PostgreSQL no está disponible.");
        }
    }

    private Map<String, Object> createWhileLocked(UUID requesterId) {
        UUID backupId = UUID.randomUUID();
        jdbc.update("INSERT INTO backup_runs(id,requested_by) VALUES (?,?)", backupId, requesterId);
        Path temporaryFile = backupDirectory.resolve(backupId + ".dump.part");
        Path finalFile = backupDirectory.resolve(backupId + ".dump");
        boolean completed = false;
        try {
            Files.createDirectories(backupDirectory);
            executePgDump(temporaryFile);
            if (!Files.isRegularFile(temporaryFile) || Files.size(temporaryFile) == 0) {
                throw new IOException("pg_dump no generó un archivo de respaldo válido.");
            }
            moveAtomically(temporaryFile, finalFile);
            String checksum = sha256(finalFile);
            sprintSixService.completeBackup(requesterId, backupId, finalFile.toString(), checksum);
            completed = true;
            return backup(backupId);
        } catch (IOException | InterruptedException | NoSuchAlgorithmException | SQLException e) {
            if (e instanceof InterruptedException) {
                Thread.currentThread().interrupt();
            }
            deleteTemporaryFile(temporaryFile);
            deleteTemporaryFile(finalFile);
            String message = e instanceof InterruptedException
                ? "La ejecución del respaldo fue interrumpida."
                : "No se pudo generar un respaldo válido: " + safeError(e);
            jdbc.update("""
                UPDATE backup_runs SET status='ERROR',error_message=?,finished_at=now()
                WHERE id=?
                """, message, backupId);
            sprintSixService.recordBackupEvent(requesterId, backupId, "FAILED",
                "Falló la generación del respaldo");
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "backup-failed", message);
        } catch (DataAccessException e) {
            deleteTemporaryFile(temporaryFile);
            if (!completed) deleteTemporaryFile(finalFile);
            throw e;
        }
    }

    public List<Map<String, Object>> history() {
        List<Map<String, Object>> runs = jdbc.queryForList("""
            SELECT id::text AS id,requested_by::text AS "requestedBy",status,
              started_at AS "startedAt",finished_at AS "finishedAt",file_path AS "filePath",
              checksum_sha256 AS checksum,"error_message" AS "errorMessage"
            FROM backup_runs
            ORDER BY started_at DESC,id DESC
            LIMIT 100
            """);
        for (Map<String, Object> run : runs) {
            Object pathValue = run.remove("filePath");
            run.put("fileName", pathValue == null ? null : Path.of(pathValue.toString()).getFileName().toString());
            run.put("sizeBytes", pathValue == null ? null : fileSize(pathValue.toString()));
        }
        return runs;
    }

    public FileSystemResource download(UUID id) {
        List<Map<String, Object>> rows = jdbc.queryForList(
            "SELECT file_path FROM backup_runs WHERE id=? AND status='COMPLETADO'", id);
        if (rows.isEmpty() || rows.getFirst().get("file_path") == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "backup-not-found",
                "No se encontró un respaldo disponible para descargar.");
        }
        Path root;
        Path file;
        try {
            root = backupDirectory.toRealPath();
            file = Path.of(rows.getFirst().get("file_path").toString()).toRealPath();
        } catch (IOException e) {
            throw new ApiException(HttpStatus.NOT_FOUND, "backup-file-unavailable",
                "El archivo de respaldo no está disponible.");
        }
        if (!file.startsWith(root) || !Files.isRegularFile(file)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "backup-file-unavailable",
                "El archivo de respaldo no está disponible.");
        }
        return new FileSystemResource(file);
    }

    public Map<String, Object> restore(UUID backupId, UUID requesterId, String requesterName) {
        maintenanceGate.beginRestoration();
        try (Connection connection = dataSource.getConnection()) {
            if (!acquireLock(connection)) {
                throw new ApiException(HttpStatus.CONFLICT, "backup-in-progress",
                    "Espera a que termine el respaldo que ya está en ejecución.");
            }
            try {
                BackupArchive target = restoreArchive(backupId);
                try {
                    executePgRestore(target.file(), true);
                } catch (IOException | InterruptedException | SQLException e) {
                    if (e instanceof InterruptedException) Thread.currentThread().interrupt();
                    recordRestoreFailure(requesterId, backupId, "No se pudo validar el archivo de respaldo.");
                    throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "backup-validation-failed",
                        "No se pudo validar el archivo para restauración: " + safeError(e));
                }

                Map<String, Object> safetyBackup = createWhileLocked(requesterId);
                UUID safetyBackupId = UUID.fromString(safetyBackup.get("id").toString());
                Path safetyBackupFile = backupDirectory.resolve(safetyBackupId + ".dump");
                try {
                    executePgRestore(target.file(), false);
                } catch (IOException | InterruptedException | SQLException e) {
                    if (e instanceof InterruptedException) Thread.currentThread().interrupt();
                    recordRestoreFailure(requesterId, backupId, "Falló la ejecución de pg_restore.");
                    throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "backup-restore-failed",
                        "No se pudo restaurar el respaldo. PostgreSQL revirtió los cambios de esta operación: "
                            + safeError(e));
                }

                try {
                    flyway.migrate();
                } catch (RuntimeException migrationError) {
                    restoreSafetyBackup(safetyBackupFile, migrationError);
                    completeRestoration(requesterId, safetyBackupId, safetyBackupId, safetyBackupFile,
                        safetyBackup.get("checksum").toString());
                    recordRestoreFailure(requesterId, backupId,
                        "La copia seleccionada no pudo migrarse; se restauró la copia de seguridad previa.");
                    throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "backup-version-incompatible",
                        "Ese respaldo no es compatible con la versión actual. Se recuperó la copia de seguridad previa.");
                }

                completeRestoration(requesterId, backupId, safetyBackupId, target.file(), target.checksum(),
                    safetyBackupFile, safetyBackup.get("checksum").toString());
                LOGGER.log(System.Logger.Level.WARNING, "Restauración autorizada por " + requesterName
                    + "; respaldo=" + backupId + "; copia de seguridad=" + safetyBackupId);
                return Map.of(
                    "status", "COMPLETADO",
                    "restoredBackupId", backupId.toString(),
                    "safetyBackupId", safetyBackupId.toString(),
                    "message", "La restauración terminó correctamente. Se conservó una copia de seguridad previa.");
            } finally {
                releaseLock(connection);
            }
        } catch (SQLException e) {
            LOGGER.log(System.Logger.Level.ERROR, "No se pudo completar la conexión para restaurar el respaldo.", e);
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "backup-restore-unavailable",
                "No se pudo restaurar el respaldo porque PostgreSQL no está disponible.");
        } finally {
            maintenanceGate.endRestoration();
        }
    }

    private Map<String, Object> backup(UUID id) {
        List<Map<String, Object>> rows = jdbc.queryForList("""
            SELECT id::text AS id,status,started_at AS "startedAt",finished_at AS "finishedAt",
              file_path AS "filePath",checksum_sha256 AS checksum,error_message AS "errorMessage"
            FROM backup_runs WHERE id=?
            """, id);
        if (rows.isEmpty()) {
            throw new IllegalStateException("No se encontró el metadato del respaldo recién creado.");
        }
        Map<String, Object> run = new LinkedHashMap<>(rows.getFirst());
        Object pathValue = run.remove("filePath");
        run.put("fileName", pathValue == null ? null : Path.of(pathValue.toString()).getFileName().toString());
        run.put("sizeBytes", pathValue == null ? null : fileSize(pathValue.toString()));
        return run;
    }

    public int removeExpiredBackups(int retentionDays) {
        if (retentionDays < 1) {
            throw new IllegalArgumentException("La retención de respaldos debe ser de al menos un día.");
        }
        List<Map<String, Object>> expired = jdbc.queryForList("""
            SELECT id::text AS id,file_path AS "filePath"
            FROM backup_runs
            WHERE status='COMPLETADO'
              AND started_at < now() - (? * interval '1 day')
            ORDER BY started_at
            """, retentionDays);

        int removed = 0;
        for (Map<String, Object> run : expired) {
            UUID id = UUID.fromString(run.get("id").toString());
            Object pathValue = run.get("filePath");
            if (pathValue != null) {
                Path file = Path.of(pathValue.toString()).toAbsolutePath().normalize();
                if (!backupDirectory.equals(file.getParent())) {
                    LOGGER.log(System.Logger.Level.ERROR,
                        "Se omitió eliminar un respaldo fuera de la carpeta configurada: " + id);
                    continue;
                }
                try {
                    Files.deleteIfExists(file);
                } catch (IOException e) {
                    LOGGER.log(System.Logger.Level.ERROR, "No se pudo eliminar el respaldo vencido: " + id, e);
                    continue;
                }
            }
            removed += jdbc.update("DELETE FROM backup_runs WHERE id=? AND status='COMPLETADO'", id);
        }
        return removed;
    }

    private boolean acquireLock(Connection connection) throws SQLException {
        try (PreparedStatement statement = connection.prepareStatement("SELECT pg_try_advisory_lock(?)")) {
            statement.setLong(1, ADVISORY_LOCK_ID);
            try (ResultSet result = statement.executeQuery()) {
                result.next();
                return result.getBoolean(1);
            }
        }
    }

    private void releaseLock(Connection connection) {
        try (PreparedStatement statement = connection.prepareStatement("SELECT pg_advisory_unlock(?)")) {
            statement.setLong(1, ADVISORY_LOCK_ID);
            try (ResultSet result = statement.executeQuery()) {
                result.next();
                if (!result.getBoolean(1)) {
                    LOGGER.log(System.Logger.Level.WARNING, "El bloqueo PostgreSQL de respaldos ya no estaba activo.");
                }
            }
        } catch (SQLException e) {
            LOGGER.log(System.Logger.Level.ERROR, "No se pudo liberar el bloqueo PostgreSQL de respaldos.", e);
        }
    }

    private void executePgDump(Path destination) throws IOException, InterruptedException, SQLException {
        HikariDataSource hikari = dataSource.unwrap(HikariDataSource.class);
        DatabaseConnection database = parseJdbcUrl(hikari.getJdbcUrl());
        ProcessBuilder builder = new ProcessBuilder(pgDumpExecutable, "--host", database.host(),
            "--port", Integer.toString(database.port()), "--username", hikari.getUsername(),
            "--no-password", "--format=custom", "--file", destination.toString(), database.name());
        builder.redirectErrorStream(true);
        builder.redirectOutput(ProcessBuilder.Redirect.DISCARD);
        Map<String, String> environment = builder.environment();
        if (hikari.getPassword() != null && !hikari.getPassword().isEmpty()) {
            environment.put("PGPASSWORD", hikari.getPassword());
        }
        if (!database.sslMode().isBlank()) {
            environment.put("PGSSLMODE", database.sslMode());
        }
        Process process = builder.start();
        if (!process.waitFor(PROCESS_TIMEOUT_MINUTES, TimeUnit.MINUTES)) {
            process.destroyForcibly();
            process.waitFor();
            throw new IOException("pg_dump excedió el tiempo máximo de ejecución.");
        }
        if (process.exitValue() != 0) {
            throw new IOException("pg_dump terminó con código " + process.exitValue() + ".");
        }
    }

    private BackupArchive restoreArchive(UUID id) {
        List<Map<String, Object>> rows = jdbc.queryForList("""
            SELECT file_path AS "filePath",checksum_sha256 AS checksum
            FROM backup_runs WHERE id=? AND status='COMPLETADO'
            """, id);
        if (rows.isEmpty() || rows.getFirst().get("filePath") == null
            || rows.getFirst().get("checksum") == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "backup-not-found",
                "No se encontró un respaldo completado para restaurar.");
        }
        try {
            Path root = backupDirectory.toRealPath();
            Path file = Path.of(rows.getFirst().get("filePath").toString()).toRealPath();
            if (!file.startsWith(root) || !Files.isRegularFile(file)) {
                throw new ApiException(HttpStatus.NOT_FOUND, "backup-file-unavailable",
                    "El archivo de respaldo no está disponible en la carpeta protegida.");
            }
            String expectedChecksum = rows.getFirst().get("checksum").toString();
            String actualChecksum = sha256(file);
            if (!MessageDigest.isEqual(expectedChecksum.getBytes(StandardCharsets.US_ASCII),
                actualChecksum.getBytes(StandardCharsets.US_ASCII))) {
                throw new ApiException(HttpStatus.CONFLICT, "backup-checksum-invalid",
                    "El checksum del respaldo no coincide. No se inició la restauración.");
            }
            return new BackupArchive(file, actualChecksum);
        } catch (IOException e) {
            throw new ApiException(HttpStatus.NOT_FOUND, "backup-file-unavailable",
                "El archivo de respaldo no está disponible.");
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("No se pudo calcular el checksum SHA-256 del respaldo.", e);
        }
    }

    private void executePgRestore(Path archive, boolean listOnly) throws IOException, InterruptedException, SQLException {
        HikariDataSource hikari = dataSource.unwrap(HikariDataSource.class);
        DatabaseConnection database = parseJdbcUrl(hikari.getJdbcUrl());
        List<String> command = new ArrayList<>();
        command.add(pgRestoreExecutable);
        if (listOnly) {
            command.add("--list");
        } else {
            command.addAll(List.of("--host", database.host(), "--port", Integer.toString(database.port()),
                "--username", hikari.getUsername(), "--no-password", "--clean", "--if-exists",
                "--single-transaction", "--exit-on-error", "--no-owner", "--no-privileges",
                "--dbname", database.name()));
        }
        command.add(archive.toString());

        Path outputFile = Files.createTempFile("clinica-pg-restore-", ".log");
        try {
            ProcessBuilder builder = new ProcessBuilder(command);
            builder.redirectErrorStream(true);
            builder.redirectOutput(outputFile.toFile());
            if (!listOnly) {
                Map<String, String> environment = builder.environment();
                if (hikari.getPassword() != null && !hikari.getPassword().isEmpty()) {
                    environment.put("PGPASSWORD", hikari.getPassword());
                }
                if (!database.sslMode().isBlank()) {
                    environment.put("PGSSLMODE", database.sslMode());
                }
            }
            Process process = builder.start();
            if (!process.waitFor(PROCESS_TIMEOUT_MINUTES, TimeUnit.MINUTES)) {
                process.destroyForcibly();
                process.waitFor();
                throw new IOException("pg_restore excedió el tiempo máximo de ejecución. " + readLogTail(outputFile));
            }
            if (process.exitValue() != 0) {
                throw new IOException("pg_restore terminó con código " + process.exitValue()
                    + ". " + readLogTail(outputFile));
            }
        } finally {
            try {
                Files.deleteIfExists(outputFile);
            } catch (IOException e) {
                LOGGER.log(System.Logger.Level.WARNING, "No se pudo limpiar el registro temporal de pg_restore.", e);
            }
        }
    }

    private String readLogTail(Path outputFile) throws IOException {
        long size = Files.size(outputFile);
        int length = (int) Math.min(size, 2_048);
        ByteBuffer buffer = ByteBuffer.allocate(length);
        try (FileChannel channel = FileChannel.open(outputFile, StandardOpenOption.READ)) {
            channel.position(Math.max(0, size - length));
            while (buffer.hasRemaining() && channel.read(buffer) != -1) {
                // Read only the bounded tail needed to diagnose a failed restore.
            }
        }
        return StandardCharsets.UTF_8.decode(buffer.flip()).toString().trim();
    }

    private void restoreSafetyBackup(Path safetyBackupFile, RuntimeException migrationError) {
        try {
            executePgRestore(safetyBackupFile, false);
            flyway.migrate();
        } catch (IOException | InterruptedException | SQLException | RuntimeException recoveryError) {
            if (recoveryError instanceof InterruptedException) Thread.currentThread().interrupt();
            LOGGER.log(System.Logger.Level.ERROR,
                "No se pudo recuperar el estado previo después de fallar la migración del respaldo.",
                recoveryError);
            migrationError.addSuppressed(recoveryError);
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "backup-recovery-failed",
                "Falló la migración y también la recuperación automática. Se requiere intervención técnica inmediata.");
        }
    }

    private void completeRestoration(UUID actorId, UUID restoredBackupId, UUID safetyBackupId,
        Path restoredFile, String restoredChecksum, Path safetyBackupFile, String safetyChecksum) {
        sprintSixService.completeRestoration(actorId, restoredBackupId, safetyBackupId,
            restoredFile.toString(), restoredChecksum, safetyBackupFile.toString(), safetyChecksum);
    }

    private void completeRestoration(UUID actorId, UUID restoredBackupId, UUID safetyBackupId,
        Path safetyBackupFile, String safetyChecksum) {
        sprintSixService.completeRestoration(actorId, restoredBackupId, safetyBackupId,
            safetyBackupFile.toString(), safetyChecksum, safetyBackupFile.toString(), safetyChecksum);
    }

    private void recordRestoreFailure(UUID actorId, UUID backupId, String description) {
        try {
            sprintSixService.recordRestoreEvent(actorId, backupId, "FAILED", description);
        } catch (DataAccessException e) {
            LOGGER.log(System.Logger.Level.ERROR, "No se pudo registrar el fallo de restauración.", e);
        }
    }

    private DatabaseConnection parseJdbcUrl(String jdbcUrl) throws IOException {
        try {
            URI uri = URI.create(jdbcUrl.substring("jdbc:".length()));
            String databaseName = uri.getPath();
            if (databaseName == null || databaseName.length() < 2) {
                throw new IllegalArgumentException();
            }
            String sslMode = "";
            if (uri.getQuery() != null) {
                for (String parameter : uri.getQuery().split("&")) {
                    String[] pair = parameter.split("=", 2);
                    if (pair.length == 2 && pair[0].equals("sslmode")) {
                        sslMode = pair[1];
                    }
                }
            }
            return new DatabaseConnection(uri.getHost(), uri.getPort() < 0 ? 5432 : uri.getPort(),
                databaseName.substring(1), sslMode);
        } catch (RuntimeException e) {
            throw new IOException("La configuración JDBC no permite preparar el respaldo.");
        }
    }

    private void moveAtomically(Path source, Path destination) throws IOException {
        try {
            Files.move(source, destination, StandardCopyOption.ATOMIC_MOVE);
        } catch (AtomicMoveNotSupportedException e) {
            Files.move(source, destination);
        }
    }

    private String sha256(Path file) throws IOException, NoSuchAlgorithmException {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (var input = Files.newInputStream(file)) {
            byte[] buffer = new byte[8192];
            int read;
            while ((read = input.read(buffer)) != -1) {
                digest.update(buffer, 0, read);
            }
        }
        return HexFormat.of().formatHex(digest.digest());
    }

    private Long fileSize(String filePath) {
        try {
            Path file = Path.of(filePath).toRealPath();
            return file.startsWith(backupDirectory) && Files.isRegularFile(file) ? Files.size(file) : null;
        } catch (IOException e) {
            return null;
        }
    }

    private void deleteTemporaryFile(Path file) {
        try {
            Files.deleteIfExists(file);
        } catch (IOException e) {
            LOGGER.log(System.Logger.Level.WARNING, "No se pudo limpiar el archivo temporal del respaldo.", e);
        }
    }

    private String safeError(Exception exception) {
        String message = exception.getMessage();
        if (message == null || message.isBlank()) {
            return exception.getClass().getSimpleName();
        }
        return message.length() > 300 ? message.substring(0, 300) : message;
    }

    private record DatabaseConnection(String host, int port, String name, String sslMode) {}
    private record BackupArchive(Path file, String checksum) {}
}
