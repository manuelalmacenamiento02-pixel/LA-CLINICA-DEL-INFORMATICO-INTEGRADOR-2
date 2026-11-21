package com.clinicainformatica.api;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.mockito.ArgumentCaptor;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ServiceIndicatorsTest {
    @Test
    void reportsAttendedAndFinalizedServicesFromRecordedTechnicalAttention() {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        Map<String, Object> technician = Map.of(
            "technicianId", "technician-id",
            "technicianName", "Ana Técnica",
            "attended", 3L,
            "finalized", 2L);
        when(jdbc.queryForMap(anyString(), any(Object[].class))).thenReturn(new HashMap<>());
        when(jdbc.queryForList(anyString(), any(Object[].class))).thenReturn(List.of(technician));
        SprintSixService service = new SprintSixService(jdbc);

        Map<String, Object> report = service.serviceIndicators(null, null, "", null);

        @SuppressWarnings("unchecked")
        List<Map<String, Object>> byTechnician =
            (List<Map<String, Object>>) report.get("byTechnician");
        assertEquals(3L, byTechnician.getFirst().get("attended"));
        assertEquals(2L, byTechnician.getFirst().get("finalized"));

        ArgumentCaptor<String> query = ArgumentCaptor.forClass(String.class);
        verify(jdbc).queryForList(query.capture(), any(Object[].class));
        assertTrue(query.getValue().contains("LEFT JOIN technical_attentions"));
        assertTrue(query.getValue().contains("count(DISTINCT attention.order_id) AS attended"));
    }
}
