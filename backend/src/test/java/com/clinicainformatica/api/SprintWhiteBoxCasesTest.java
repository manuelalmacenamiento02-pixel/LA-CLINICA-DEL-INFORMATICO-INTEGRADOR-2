package com.clinicainformatica.api;

import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** Five business paths; database/HTTP integration is outside these unit tests. */
class SprintWhiteBoxCasesTest {
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final ClinicRepository clinic = mock(ClinicRepository.class);
    private final TechnicalAttentionRepository attention = mock(TechnicalAttentionRepository.class);
    private final HttpServletRequest request = mock(HttpServletRequest.class);
    private final UUID actorId = UUID.fromString("11111111-1111-4111-8111-111111111111");
    private final UUID orderId = UUID.fromString("22222222-2222-4222-8222-222222222222");
    private final UUID attentionId = UUID.fromString("33333333-3333-4333-8333-333333333333");

    private ClinicController controller() {
        when(clinic.jdbc()).thenReturn(jdbc);
        when(request.getAttribute("currentUser")).thenReturn(Map.of(
            "id", actorId.toString(), "role", "ADMINISTRADOR"));
        return new ClinicController(clinic);
    }

    @Test
    void cbLogin001Sprint1RejectsWrongPassword() {
        var controller = controller();
        String hash = new BCryptPasswordEncoder(4).encode("Correcta2026!");
        when(jdbc.queryForList(anyString(), eq("qa"))).thenReturn(List.of(Map.of(
            "id", actorId, "password_hash", hash, "active", true, "role_code", "TÉCNICO")));

        ApiException error = assertThrows(ApiException.class, () -> controller.login(
            new ClinicController.Login("qa", "Incorrecta2026!"), request));

        assertEquals(HttpStatus.UNAUTHORIZED, error.status);
        assertEquals("invalid-credentials", error.code);
        assertEquals("El usuario o la contraseña son incorrectos.", error.getMessage());
        verify(request, never()).getSession(anyBoolean());
        verify(jdbc).queryForList(anyString(), eq("qa"));
        verifyNoMoreInteractions(jdbc);
        verify(clinic).audit(isNull(), eq("LOGIN_FAILED"), eq("users"), isNull(),
            eq("FAILED"), anyString());
    }

    @Test
    void cbClient002Sprint2AcceptsValidClient() {
        var controller = controller();
        var draft = new ClinicController.ClientDraft("DNI", "87654321", "Ana", "Prueba",
            "987654321", "ana.qa@example.com", "Dirección QA", "Registro de prueba");
        when(jdbc.update(startsWith("INSERT INTO clients"), any(UUID.class), eq("DNI"),
            eq("87654321"), eq("Ana"), eq("Prueba"), eq("987654321"),
            eq("ana.qa@example.com"), eq("Dirección QA"), eq("Registro de prueba"))).thenReturn(1);
        when(jdbc.queryForObject(eq("SELECT * FROM clients WHERE id=?"),
            org.mockito.ArgumentMatchers.<RowMapper<Map<String, Object>>>any(), any(UUID.class)))
            .thenAnswer(invocation -> Map.of("id", invocation.<UUID>getArgument(2).toString(),
                "documentNumber", "87654321", "firstName", "Ana"));

        Map<String, Object> result = assertDoesNotThrow(() -> controller.createClient(draft, request));

        UUID createdId = UUID.fromString((String) result.get("id"));
        assertEquals("87654321", result.get("documentNumber"));
        verify(jdbc).update(startsWith("INSERT INTO clients"), eq(createdId), eq("DNI"),
            eq("87654321"), eq("Ana"), eq("Prueba"), eq("987654321"),
            eq("ana.qa@example.com"), eq("Dirección QA"), eq("Registro de prueba"));
        verify(clinic).audit(actorId, "CREATE", "clients", createdId);
    }

    @Test
    void cbOrder003Sprint3AcceptsActiveTechnician() {
        var controller = controller();
        UUID technicianId = UUID.fromString("44444444-4444-4444-8444-444444444444");
        when(jdbc.queryForList(anyString(), eq(orderId)))
            .thenReturn(List.of(Map.of("status_code", "PENDIENTE")));
        when(jdbc.queryForObject(anyString(), eq(Boolean.class), eq(technicianId))).thenReturn(true);
        when(clinic.serviceOrder(orderId, null))
            .thenReturn(Map.of("id", orderId.toString(), "technicianId", technicianId.toString()));

        Map<String, Object> result = assertDoesNotThrow(() -> controller.assignTechnician(
            orderId, new ClinicController.TechnicianAssignment(technicianId, "Asignación QA"), request));

        assertEquals(technicianId.toString(), result.get("technicianId"));
        verify(jdbc).update(startsWith("UPDATE technician_assignments"), eq(orderId));
        verify(jdbc).update(contains("INSERT INTO technician_assignments"),
            eq(orderId), eq(technicianId), eq(actorId), eq("Asignación QA"));
        verify(clinic).audit(actorId, "ASSIGN_TECHNICIAN", "service_orders", orderId);
    }

    private TechnicalAttentionService readyToClose(String diagnosis) {
        when(jdbc.queryForObject(anyString(), eq(Boolean.class), eq(orderId), eq(actorId)))
            .thenReturn(true);
        when(jdbc.queryForList(anyString(), eq(orderId)))
            .thenReturn(List.of(Map.of("status_code", "EN_ATENCION")));
        when(attention.attention(orderId)).thenReturn(Map.of("id", attentionId.toString(),
            "diagnosis", diagnosis, "actionsPerformed", "Revisión de conectores",
            "resultSummary", "Funcionamiento restablecido"));
        return new TechnicalAttentionService(jdbc, attention, clinic);
    }

    private Map<String, Object> technician() {
        return Map.of("id", actorId.toString(), "role", "TÉCNICO");
    }

    @Test
    void cbClose004Sprint4RejectsIncompleteAttention() {
        var service = readyToClose("");

        ApiException error = assertThrows(ApiException.class,
            () -> service.finalizeOrder(orderId, actorId, technician()));

        assertEquals(HttpStatus.CONFLICT, error.status);
        assertEquals("attention-incomplete", error.code);
        assertEquals("Completa el diagnóstico, las actividades realizadas y el resultado antes de finalizar.",
            error.getMessage());
        verify(jdbc).queryForObject(anyString(), eq(Boolean.class), eq(orderId), eq(actorId));
        verify(jdbc).queryForList(anyString(), eq(orderId));
        verify(attention).attention(orderId);
        verifyNoMoreInteractions(jdbc, attention);
        verifyNoInteractions(clinic);
    }

    @Test
    void cbClose005Sprint4AcceptsCompleteAttention() {
        var service = readyToClose("Conector de alimentación defectuoso");
        when(jdbc.query(anyString(), org.mockito.ArgumentMatchers.<RowMapper<UUID>>any(), eq(orderId)))
            .thenReturn(List.of(actorId));

        Map<String, Object> result = assertDoesNotThrow(
            () -> service.finalizeOrder(orderId, actorId, technician()));

        assertEquals(orderId.toString(), result.get("id"));
        assertEquals("FINALIZADA", result.get("status"));
        verify(jdbc).update(contains("UPDATE technical_attentions"), eq(actorId), eq(attentionId));
        verify(jdbc).update(contains("UPDATE service_orders"), eq(actorId), eq(orderId));
        verify(jdbc).update(contains("INSERT INTO order_status_history"), eq(orderId), eq(actorId));
        verify(clinic).audit(actorId, "FINALIZE_SERVICE_ORDER", "service_orders", orderId);
    }
}
