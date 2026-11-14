package com.clinicainformatica.api;

import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class OrderAssignmentWhiteBoxTest {
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final ClinicRepository repository = mock(ClinicRepository.class);
    private final HttpServletRequest request = mock(HttpServletRequest.class);
    private final UUID orderId = UUID.fromString("22222222-2222-4222-8222-222222222222");
    private final UUID technicianId = UUID.fromString("44444444-4444-4444-8444-444444444444");
    private final UUID actorId = UUID.fromString("11111111-1111-4111-8111-111111111111");
    private static final String ORDER_QUERY =
        "SELECT status_code FROM service_orders WHERE id=? FOR UPDATE";
    private static final String TECHNICIAN_QUERY =
        "SELECT EXISTS(SELECT 1 FROM users WHERE id=? AND active AND role_code='TÉCNICO')";

    private ClinicController prepare(boolean activeTechnician) {
        when(repository.jdbc()).thenReturn(jdbc);
        when(jdbc.queryForList(ORDER_QUERY, orderId))
            .thenReturn(List.of(Map.of("status_code", "PENDIENTE")));
        when(jdbc.queryForObject(TECHNICIAN_QUERY, Boolean.class, technicianId))
            .thenReturn(activeTechnician);
        return new ClinicController(repository);
    }

    @Test
    @DisplayName("CB-ORDER-003: rechazar asignación a técnico inactivo")
    void cbOrder003RejectsInactiveTechnicianBeforeWrites() {
        var controller = prepare(false);

        ApiException error = assertThrows(ApiException.class, () -> controller.assignTechnician(
            orderId, new ClinicController.TechnicianAssignment(technicianId, "Asignación QA"), request));

        assertEquals(HttpStatus.BAD_REQUEST, error.status);
        assertEquals("invalid-technician", error.code);
        assertEquals("Selecciona un técnico activo registrado.", error.getMessage());
        var sequence = inOrder(jdbc);
        sequence.verify(jdbc).queryForList(ORDER_QUERY, orderId);
        sequence.verify(jdbc).queryForObject(TECHNICIAN_QUERY, Boolean.class, technicianId);
        verifyNoMoreInteractions(jdbc);
        verify(repository, times(2)).jdbc();
        verifyNoMoreInteractions(repository);
        verifyNoInteractions(request);
    }

    @Test
    @DisplayName("CB-ORDER-004: asignar una orden a un técnico activo")
    void cbOrder004AssignsActiveTechnicianAndAudits() {
        var controller = prepare(true);
        when(request.getAttribute("currentUser"))
            .thenReturn(Map.of("id", actorId.toString(), "role", "ADMINISTRADOR"));
        String endAssignment =
            "UPDATE technician_assignments SET ended_at=now() WHERE order_id=? AND ended_at IS NULL";
        when(jdbc.update(endAssignment, orderId)).thenReturn(1);
        when(jdbc.update(contains("INSERT INTO technician_assignments"),
            eq(orderId), eq(technicianId), eq(actorId), eq("Asignación QA"))).thenReturn(1);
        Map<String, Object> expected = Map.of("id", orderId.toString(),
            "technicianId", technicianId.toString(), "status", "PENDIENTE");
        when(repository.serviceOrder(orderId, null)).thenReturn(expected);

        Map<String, Object> result = assertDoesNotThrow(() -> controller.assignTechnician(
            orderId, new ClinicController.TechnicianAssignment(technicianId, " Asignación QA "), request));

        assertEquals(expected, result);
        var sequence = inOrder(jdbc);
        sequence.verify(jdbc).queryForList(ORDER_QUERY, orderId);
        sequence.verify(jdbc).queryForObject(TECHNICIAN_QUERY, Boolean.class, technicianId);
        sequence.verify(jdbc).update(endAssignment, orderId);
        sequence.verify(jdbc).update(contains("INSERT INTO technician_assignments"),
            eq(orderId), eq(technicianId), eq(actorId), eq("Asignación QA"));
        verifyNoMoreInteractions(jdbc);
        var finalSteps = inOrder(repository);
        finalSteps.verify(repository).audit(actorId, "ASSIGN_TECHNICIAN", "service_orders", orderId);
        finalSteps.verify(repository).serviceOrder(orderId, null);
    }
}
