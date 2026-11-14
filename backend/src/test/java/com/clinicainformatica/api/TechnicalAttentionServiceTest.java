package com.clinicainformatica.api;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

class TechnicalAttentionServiceTest {
    @Test
    void cbClose001RejectsEmptyDiagnosisWithoutWriting() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        TechnicalAttentionRepository repository = mock(TechnicalAttentionRepository.class);
        ClinicRepository clinic = mock(ClinicRepository.class);
        var service = new TechnicalAttentionService(jdbc, repository, clinic);
        UUID orderId = UUID.randomUUID();
        UUID actorId = UUID.randomUUID();
        Map<String, Object> actor = Map.of("id", actorId.toString(), "role", "TÉCNICO");
        when(jdbc.queryForObject(anyString(), eq(Boolean.class), eq(orderId), eq(actorId)))
            .thenReturn(true);
        when(jdbc.queryForList(anyString(), eq(orderId)))
            .thenReturn(List.of(Map.<String, Object>of("status_code", "EN_ATENCION")));
        when(repository.attention(orderId)).thenReturn(Map.of(
            "diagnosis", "", "actionsPerformed", "Inspección del equipo",
            "resultSummary", "Evaluación realizada"));

        ApiException error = assertThrows(ApiException.class,
            () -> service.finalizeOrder(orderId, actorId, actor));

        assertEquals(HttpStatus.CONFLICT, error.status);
        assertEquals("attention-incomplete", error.code);
        assertEquals("Completa el diagnóstico, las actividades realizadas y el resultado antes de finalizar.",
            error.getMessage());
        verify(jdbc).queryForObject(anyString(), eq(Boolean.class), eq(orderId), eq(actorId));
        verify(jdbc).queryForList(anyString(), eq(orderId));
        verify(repository).attention(orderId);
        // Any write, audit or later query would be an unexpected interaction.
        verifyNoMoreInteractions(jdbc, repository);
        verifyNoInteractions(clinic);
    }
}
