package com.clinicainformatica.api;

import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class BackupSchedulerTest {
    @Test
    void continuesRetentionWhenAutomaticBackupFails() {
        BackupService backupService = mock(BackupService.class);
        when(backupService.create(null)).thenThrow(
            new ApiException(org.springframework.http.HttpStatus.SERVICE_UNAVAILABLE,
                "backup-failed", "No se pudo generar el respaldo."));
        when(backupService.removeExpiredBackups(30)).thenReturn(2);
        BackupScheduler scheduler = new BackupScheduler(backupService, 30);

        assertDoesNotThrow(scheduler::runDailyMaintenance);

        verify(backupService).create(null);
        verify(backupService).removeExpiredBackups(30);
    }

    @Test
    void logsStorageFailureWithoutStoppingScheduler() {
        BackupService backupService = mock(BackupService.class);
        when(backupService.create(null)).thenReturn(Map.of("id", "backup-id"));
        when(backupService.removeExpiredBackups(30))
            .thenThrow(new DataAccessResourceFailureException("database unavailable"));
        BackupScheduler scheduler = new BackupScheduler(backupService, 30);

        assertDoesNotThrow(scheduler::runDailyMaintenance);

        verify(backupService).create(null);
        verify(backupService).removeExpiredBackups(30);
    }
}
