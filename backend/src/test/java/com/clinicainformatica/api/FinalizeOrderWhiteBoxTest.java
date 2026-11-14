package com.clinicainformatica.api;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class FinalizeOrderWhiteBoxTest {
    private final JdbcTemplate jdbc = mock(JdbcTemplate.class);
    private final TechnicalAttentionRepository repository = mock(TechnicalAttentionRepository.class);
    private final ClinicRepository clinic = mock(ClinicRepository.class);
    private final UUID orderId = UUID.fromString("22222222-2222-4222-8222-222222222222");
    private final UUID actorId = UUID.fromString("11111111-1111-4111-8111-111111111111");
    private final UUID attentionId = UUID.fromString("33333333-3333-4333-8333-333333333333");
    private final Map<String, Object> actor = Map.of("id", actorId.toString(), "role", "TÉCNICO");

    private TechnicalAttentionService prepare(String diagnosis) {
        when(jdbc.queryForObject(anyString(), eq(Boolean.class), eq(orderId), eq(actorId)))
            .thenReturn(true);
        when(jdbc.queryForList("SELECT status_code FROM service_orders WHERE id=? FOR UPDATE", orderId))
            .thenReturn(List.of(Map.of("status_code", "EN_ATENCION")));
        when(repository.attention(orderId)).thenReturn(Map.of("id", attentionId.toString(),
            "diagnosis", diagnosis, "actionsPerformed", "Sustitución del conector",
            "resultSummary", "Equipo funcionando correctamente"));
        return new TechnicalAttentionService(jdbc, repository, clinic);
    }

    @Test
    @DisplayName("CB-CLOSE-004: rechazar cierre con diagnóstico compuesto solo por espacios")
    void cbClose004RejectsWhitespaceDiagnosisWithoutWrites() {
        var service = prepare(" \t ");

        ApiException error = assertThrows(ApiException.class,
            () -> service.finalizeOrder(orderId, actorId, actor));

        assertEquals(HttpStatus.CONFLICT, error.status);
        assertEquals("attention-incomplete", error.code);
        assertEquals("Completa el diagnóstico, las actividades realizadas y el resultado antes de finalizar.",
            error.getMessage());
        verify(jdbc).queryForObject(anyString(), eq(Boolean.class), eq(orderId), eq(actorId));
        verify(jdbc).queryForList("SELECT status_code FROM service_orders WHERE id=? FOR UPDATE", orderId);
        verify(repository).attention(orderId);
        verifyNoMoreInteractions(jdbc, repository);
        verifyNoInteractions(clinic);
    }

    @Test
    @DisplayName("CB-CLOSE-005: finalizar orden con atención completa y técnico activo asignado")
    void cbClose005FinalizesCompleteAttentionInOrder() {
        var service = prepare("Conector de alimentación defectuoso");
        when(jdbc.query(anyString(), org.mockito.ArgumentMatchers.<RowMapper<UUID>>any(), eq(orderId)))
            .thenReturn(List.of(actorId));
        when(jdbc.update(contains("UPDATE technical_attentions"), eq(actorId), eq(attentionId)))
            .thenReturn(1);
        when(jdbc.update(contains("UPDATE service_orders"), eq(actorId), eq(orderId)))
            .thenReturn(1);
        when(jdbc.update(contains("INSERT INTO order_status_history"), eq(orderId), eq(actorId)))
            .thenReturn(1);

        Map<String, Object> result = assertDoesNotThrow(
            () -> service.finalizeOrder(orderId, actorId, actor));

        assertEquals(Map.of("id", orderId.toString(), "status", "FINALIZADA"), result);
        var sequence = inOrder(jdbc, repository, clinic);
        sequence.verify(jdbc).queryForObject(anyString(), eq(Boolean.class), eq(orderId), eq(actorId));
        sequence.verify(jdbc).queryForList("SELECT status_code FROM service_orders WHERE id=? FOR UPDATE", orderId);
        sequence.verify(repository).attention(orderId);
        sequence.verify(jdbc).query(anyString(), org.mockito.ArgumentMatchers.<RowMapper<UUID>>any(), eq(orderId));
        sequence.verify(jdbc).update(contains("UPDATE technical_attentions"), eq(actorId), eq(attentionId));
        sequence.verify(jdbc).update(contains("UPDATE service_orders"), eq(actorId), eq(orderId));
        sequence.verify(jdbc).update(contains("INSERT INTO order_status_history"), eq(orderId), eq(actorId));
        sequence.verify(clinic).audit(actorId, "FINALIZE_SERVICE_ORDER", "service_orders", orderId);
        verifyNoMoreInteractions(jdbc, repository, clinic);
    }
}
