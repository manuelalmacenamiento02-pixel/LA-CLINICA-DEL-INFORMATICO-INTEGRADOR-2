package com.clinicainformatica.api;

import com.zaxxer.hikari.HikariDataSource;
import java.io.IOException;
import java.net.URI;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import javax.sql.DataSource;
import org.springframework.beans.factory.annotation.Value;
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

    public BackupService(JdbcTemplate jdbc, DataSource dataSource, SprintSixService sprintSixService,
        @Value("${clinica.backup.directory:${user.home}/clinica-backups}") String backupDirectory,
        @Value("${clinica.backup.pg-dump:pg_dump}") String pgDumpExecutable) {
        this.jdbc = jdbc;
        this.dataSource = dataSource;
        this.sprintSixService = sprintSixService;
        this.backupDirectory = Path.of(backupDirectory).toAbsolutePath().normalize();
        this.pgDumpExecutable = pgDumpExecutable;
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
}
