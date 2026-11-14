package com.clinicainformatica.api;

import java.sql.ResultSet;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class EquipmentRowMappingTest {
    @Test
    void cbMap001MapsDatabaseColumnsToEquipmentResponse() throws Exception {
        JdbcTemplate jdbc = mock(JdbcTemplate.class);
        ResultSet rs = mock(ResultSet.class);
        var repository = new ClinicRepository(jdbc);
        when(rs.getString("id")).thenReturn("equipo-qa");
        when(rs.getString("client_id")).thenReturn("cliente-qa");
        when(rs.getString("type")).thenReturn("Laptop");
        when(rs.getString("brand")).thenReturn("Lenovo");
        when(rs.getString("model")).thenReturn("ThinkPad E14");
        when(rs.getString("serial_number")).thenReturn("QA-MAP-001");
        when(rs.getString("characteristics")).thenReturn("8 GB RAM");
        when(rs.getString("accessories")).thenReturn("Cargador");
        when(rs.getString("observations")).thenReturn("Equipo de pruebas");

        Map<String, Object> result = repository.equipmentRow(rs, 0);

        assertEquals(Map.of(
            "id", "equipo-qa",
            "clientId", "cliente-qa",
            "type", "Laptop",
            "brand", "Lenovo",
            "model", "ThinkPad E14",
            "serialNumber", "QA-MAP-001",
            "characteristics", "8 GB RAM",
            "accessories", "Cargador",
            "observations", "Equipo de pruebas"), result);
        assertFalse(result.containsKey("client_id"));
        assertFalse(result.containsKey("serial_number"));
        verify(rs, never()).next();
        verifyNoInteractions(jdbc);
    }
}
