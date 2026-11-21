package com.clinicainformatica.api;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import javax.sql.DataSource;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.flywaydb.core.Flyway;
import org.springframework.jdbc.core.JdbcTemplate;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class BackupRetentionTest {
    @TempDir
    Path temporaryDirectory;

    @Test
    void removesExpiredFilesAndTheirHistory() throws Exception {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        Path backupDirectory = temporaryDirectory.resolve("backups");
        Files.createDirectories(backupDirectory);
        Path expiredFile = Files.createFile(backupDirectory.resolve("expired.dump"));
        UUID backupId = UUID.randomUUID();
        when(jdbc.queryForList(anyString(), eq(30))).thenReturn(List.of(
            Map.of("id", backupId.toString(), "filePath", expiredFile.toString())));
        when(jdbc.update("DELETE FROM backup_runs WHERE id=? AND status='COMPLETADO'", backupId))
            .thenReturn(1);
        BackupService service = new BackupService(jdbc, mock(DataSource.class),
            mock(SprintSixService.class), backupDirectory.toString(), "pg_dump", "pg_restore",
            mock(BackupMaintenanceGate.class), mock(Flyway.class));

        assertEquals(1, service.removeExpiredBackups(30));

        assertFalse(Files.exists(expiredFile));
        verify(jdbc).update("DELETE FROM backup_runs WHERE id=? AND status='COMPLETADO'", backupId);
    }

    @Test
    void leavesFilesOutsideBackupDirectoryUntouched() throws Exception {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        Path outsideFile = Files.createFile(temporaryDirectory.resolve("outside.dump"));
        UUID backupId = UUID.randomUUID();
        when(jdbc.queryForList(anyString(), eq(30))).thenReturn(List.of(
            Map.of("id", backupId.toString(), "filePath", outsideFile.toString())));
        BackupService service = new BackupService(jdbc, mock(DataSource.class),
            mock(SprintSixService.class), temporaryDirectory.resolve("backups").toString(),
            "pg_dump", "pg_restore", mock(BackupMaintenanceGate.class), mock(Flyway.class));

        assertEquals(0, service.removeExpiredBackups(30));

        assertTrue(Files.exists(outsideFile));
    }

    @Test
    void rejectsNonPositiveRetention() {
        BackupService service = new BackupService(mock(JdbcTemplate.class), mock(DataSource.class),
            mock(SprintSixService.class), temporaryDirectory.toString(), "pg_dump", "pg_restore",
            mock(BackupMaintenanceGate.class), mock(Flyway.class));

        assertThrows(IllegalArgumentException.class, () -> service.removeExpiredBackups(0));
    }
}
