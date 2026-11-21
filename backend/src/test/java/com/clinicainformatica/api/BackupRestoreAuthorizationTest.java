package com.clinicainformatica.api;

import java.util.Map;
import java.util.UUID;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class BackupRestoreAuthorizationTest {
    private static final UUID BACKUP_ID =
        UUID.fromString("22222222-2222-4222-8222-222222222222");
    private static final UUID ADMIN_ID =
        UUID.fromString("11111111-1111-4111-8111-111111111111");

    @Test
    void rejectsRestoreRequestsFromNonAdministrators() {
        BackupService backupService = mock(BackupService.class);
        SprintSixController controller = new SprintSixController(
            mock(SprintSixService.class), backupService, "");
        HttpServletRequest request = mock(HttpServletRequest.class);
        when(request.getAttribute("currentUser")).thenReturn(Map.of(
            "id", ADMIN_ID.toString(),
            "role", "TÉCNICO",
            "firstName", "Técnico",
            "lastName", "Prueba"));

        ApiException error = assertThrows(ApiException.class,
            () -> controller.restoreBackup(BACKUP_ID, request));

        assertEquals(org.springframework.http.HttpStatus.FORBIDDEN, error.status);
        verify(backupService, never()).restore(BACKUP_ID, ADMIN_ID, "Técnico Prueba");
    }

    @Test
    void passesAdministratorIdentityToRestoreService() {
        BackupService backupService = mock(BackupService.class);
        when(backupService.restore(BACKUP_ID, ADMIN_ID, "Admin Prueba"))
            .thenReturn(Map.of("status", "COMPLETADO"));
        SprintSixController controller = new SprintSixController(
            mock(SprintSixService.class), backupService, "");
        HttpServletRequest request = mock(HttpServletRequest.class);
        when(request.getAttribute("currentUser")).thenReturn(Map.of(
            "id", ADMIN_ID.toString(),
            "role", "ADMINISTRADOR",
            "firstName", "Admin",
            "lastName", "Prueba"));

        Map<String, Object> response = controller.restoreBackup(BACKUP_ID, request);

        assertEquals("COMPLETADO", response.get("status"));
        verify(backupService).restore(BACKUP_ID, ADMIN_ID, "Admin Prueba");
    }
}
