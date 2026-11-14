package com.clinicainformatica.api;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TechnicalAttentionService {
    private final JdbcTemplate jdbc;
    private final TechnicalAttentionRepository repository;
    private final ClinicRepository clinicRepository;

    public TechnicalAttentionService(JdbcTemplate jdbc, TechnicalAttentionRepository repository,
        ClinicRepository clinicRepository) {
        this.jdbc = jdbc;
        this.repository = repository;
        this.clinicRepository = clinicRepository;
    }

    public void requireCanAttend(UUID orderId, Map<String, Object> actor) {
        UUID actorId = UUID.fromString((String) actor.get("id"));
        String role = (String) actor.get("role");
        if ("TÉCNICO".equals(role)) {
            boolean assigned = Boolean.TRUE.equals(jdbc.queryForObject("""
                SELECT EXISTS(
                  SELECT 1 FROM technician_assignments
                  WHERE order_id=? AND technician_id=? AND ended_at IS NULL
                )
                """, Boolean.class, orderId, actorId));
            if (!assigned) {
                throw new ApiException(HttpStatus.NOT_FOUND, "not-found",
                    "No se encontró una orden asignada a este técnico.");
            }
        } else if (!clinicRepository.can(role, "attend-orders")) {
            throw new ApiException(HttpStatus.FORBIDDEN, "forbidden",
                "No tienes permiso para registrar una atención técnica.");
        }
    }

    public Map<String, Object> attention(UUID orderId, Map<String, Object> actor) {
        requireCanAttend(orderId, actor);
        requireOrder(orderId, false);
        return repository.attention(orderId);
    }

    @Transactional
    public Map<String, Object> save(UUID orderId, UUID actorId, Map<String, Object> actor,
        LocalDate attendedAt, String diagnosis, String actionsPerformed, String performedTests,
        String partsUsed, String observations, String resultSummary) {
        requireCanAttend(orderId, actor);
        Map<String, Object> order = requireOrder(orderId, true);
        if ("FINALIZADA".equals(order.get("status_code"))) {
            throw new ApiException(HttpStatus.CONFLICT, "order-finalized",
                "No se pueden modificar atenciones de una orden finalizada.");
        }
        if (attendedAt.isAfter(LocalDate.now())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "invalid-data",
                "La fecha de atención no puede ser futura.");
        }
        UUID assignedTechnician = assignedTechnician(orderId);
        UUID attentionId = repository.saveAttention(orderId, assignedTechnician, actorId, attendedAt, diagnosis.trim(),
            actionsPerformed.trim(), performedTests.trim(), partsUsed.trim(), observations.trim(),
            resultSummary.trim());
        clinicRepository.audit(actorId,"SAVE_TECHNICAL_ATTENTION","technical_attentions",attentionId,
            "SUCCESS","Registro o actualización de atención técnica");
        return repository.attention(orderId);
    }

    @Transactional
    public Map<String, Object> finalizeOrder(UUID orderId, UUID actorId, Map<String, Object> actor) {
        requireCanAttend(orderId, actor);
        Map<String, Object> order = requireOrder(orderId, true);
        if ("FINALIZADA".equals(order.get("status_code"))) {
            throw new ApiException(HttpStatus.CONFLICT, "order-finalized",
                "La orden ya está finalizada.");
        }
        if (!"EN_ATENCION".equals(order.get("status_code"))) {
            throw new ApiException(HttpStatus.CONFLICT, "attention-not-started",
                "Inicia la atención antes de finalizar la orden.");
        }
        Map<String, Object> attention = repository.attention(orderId);
        if (attention == null || blank(attention.get("diagnosis"))
            || blank(attention.get("actionsPerformed")) || blank(attention.get("resultSummary"))) {
            throw new ApiException(HttpStatus.CONFLICT, "attention-incomplete",
                "Completa el diagnóstico, las actividades realizadas y el resultado antes de finalizar.");
        }
        assignedTechnician(orderId);
        jdbc.update("""
            UPDATE technical_attentions
            SET finished_at=now(),updated_by=?
            WHERE id=? AND finished_at IS NULL
            """, actorId, UUID.fromString((String) attention.get("id")));
        jdbc.update("""
            UPDATE service_orders
            SET status_code='FINALIZADA',finalized_at=now(),finalized_by=?
            WHERE id=?
            """, actorId, orderId);
        jdbc.update("""
            INSERT INTO order_status_history(order_id,from_status,to_status,changed_by,reason)
            VALUES (?,'EN_ATENCION','FINALIZADA',?,'Atención técnica finalizada')
            """, orderId, actorId);
        clinicRepository.audit(actorId, "FINALIZE_SERVICE_ORDER", "service_orders", orderId);
        return Map.of("id", orderId.toString(), "status", "FINALIZADA");
    }

    public List<Map<String, Object>> prediagnoses(UUID orderId, Map<String, Object> actor) {
        requireCanAttend(orderId, actor);
        requireOrder(orderId, false);
        return repository.prediagnoses(orderId);
    }

    private Map<String, Object> requireOrder(UUID orderId, boolean lock) {
        String sql = "SELECT status_code FROM service_orders WHERE id=?" + (lock ? " FOR UPDATE" : "");
        var rows = jdbc.queryForList(sql, orderId);
        if (rows.isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "not-found", "No se encontró la orden.");
        }
        return rows.getFirst();
    }

    private boolean blank(Object value) {
        return value == null || value.toString().isBlank();
    }

    private UUID assignedTechnician(UUID orderId) {
        List<UUID> technicians = jdbc.query("""
            SELECT assignment.technician_id FROM technician_assignments assignment
            JOIN users technician ON technician.id=assignment.technician_id
            WHERE assignment.order_id=? AND assignment.ended_at IS NULL
              AND technician.active AND technician.role_code='TÉCNICO'
            """, (result, rowNumber) -> result.getObject("technician_id", UUID.class), orderId);
        if (technicians.isEmpty()) {
            throw new ApiException(HttpStatus.CONFLICT, "technician-required",
                "La orden debe tener un técnico activo asignado.");
        }
        return technicians.getFirst();
    }
}
