package com.clinicainformatica.api;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataAccessException;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class BackupScheduler {
    private static final System.Logger LOGGER = System.getLogger(BackupScheduler.class.getName());

    private final BackupService backupService;
    private final int retentionDays;

    public BackupScheduler(BackupService backupService,
        @Value("${clinica.backup.retention-days:30}") int retentionDays) {
        this.backupService = backupService;
        this.retentionDays = retentionDays;
    }

    @Scheduled(cron = "${clinica.backup.schedule:0 0 2 * * *}",
        zone = "${clinica.backup.schedule-zone:UTC}")
    void runDailyMaintenance() {
        try {
            var backup = backupService.create(null);
            LOGGER.log(System.Logger.Level.INFO, "Respaldo automático completado: " + backup.get("id"));
        } catch (ApiException | DataAccessException e) {
            LOGGER.log(System.Logger.Level.ERROR, "Falló la generación automática del respaldo.", e);
        }

        try {
            int removed = backupService.removeExpiredBackups(retentionDays);
            LOGGER.log(System.Logger.Level.INFO, "Respaldos vencidos eliminados: " + removed);
        } catch (DataAccessException e) {
            LOGGER.log(System.Logger.Level.ERROR, "No se pudo aplicar la retención de respaldos.", e);
        }
    }
}
