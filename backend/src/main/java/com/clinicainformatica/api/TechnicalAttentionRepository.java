package com.clinicainformatica.api;

import java.sql.Timestamp;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class TechnicalAttentionRepository {
    private final JdbcTemplate jdbc;

    public TechnicalAttentionRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Map<String, Object> attention(UUID orderId) {
        var rows = jdbc.queryForList("""
            SELECT attention.id::text AS id,attention.order_id::text AS "orderId",
              attention.technician_id::text AS "technicianId",
              btrim(technician.first_name || ' ' || technician.last_name) AS "technicianName",
              attention.started_at::text AS "attendedAt",attention.diagnosis,
              attention.actions_performed AS "actionsPerformed",
              attention.performed_tests AS "performedTests",attention.parts_used AS "partsUsed",
              attention.observations,attention.result_summary AS "resultSummary",
              attention.finished_at::text AS "finishedAt"
            FROM technical_attentions attention
            JOIN users technician ON technician.id=attention.technician_id
            WHERE attention.order_id=?
            ORDER BY attention.created_at DESC,attention.id DESC
            LIMIT 1
            """, orderId);
        return rows.isEmpty() ? null : rows.getFirst();
    }

    public UUID saveAttention(UUID orderId, UUID technicianId, UUID actorId, LocalDate attendedAt,
        String diagnosis, String actionsPerformed, String performedTests, String partsUsed,
        String observations, String resultSummary) {
        var current = jdbc.queryForList("""
            SELECT id FROM technical_attentions
            WHERE order_id=? AND finished_at IS NULL
            ORDER BY created_at DESC,id DESC
            LIMIT 1
            """, orderId);
        if (current.isEmpty()) {
            UUID id = UUID.randomUUID();
            jdbc.update("""
                INSERT INTO technical_attentions(id,order_id,technician_id,updated_by,diagnosis,
                  actions_performed,performed_tests,parts_used,observations,result_summary,started_at)
                VALUES (?,?,?,?,?,?,?,?,?,?,?)
                """, id, orderId, technicianId, actorId, diagnosis, actionsPerformed, performedTests,
                partsUsed, observations, resultSummary,
                Timestamp.valueOf(attendedAt.atStartOfDay()));
            return id;
        }
        UUID id = (UUID) current.getFirst().get("id");
        jdbc.update("""
            UPDATE technical_attentions SET technician_id=?,updated_by=?,diagnosis=?,
              actions_performed=?,performed_tests=?,parts_used=?,observations=?,result_summary=?,
              started_at=? WHERE id=? AND finished_at IS NULL
            """, technicianId, actorId, diagnosis, actionsPerformed, performedTests, partsUsed,
            observations, resultSummary, Timestamp.valueOf(attendedAt.atStartOfDay()), id);
        return id;
    }

    public List<Map<String, Object>> prediagnoses(UUID orderId) {
        return jdbc.queryForList("""
            SELECT prediction.id::text AS id,prediction.status,prediction.model,
            prediction.generated_diagnosis AS "originalResponse",prediction.result_data::text AS "resultJson",
              prediction.error_message AS "errorMessage",prediction.requested_at::text AS "requestedAt",
              prediction.completed_at::text AS "completedAt",
            validation.decision AS "validationStatus",validation.modified_data::text AS "modifiedJson",
              validation.observations AS "validationObservations",
              validation.validated_at::text AS "validatedAt",
              btrim(technician.first_name || ' ' || technician.last_name) AS "validatedBy"
            FROM ai_prediagnoses prediction
            LEFT JOIN ai_validations validation ON validation.prediagnosis_id=prediction.id
            LEFT JOIN users technician ON technician.id=validation.technician_id
            WHERE prediction.order_id=?
            ORDER BY prediction.requested_at DESC,prediction.id DESC
            """, orderId);
    }

    public Map<String, Object> prediagnosis(UUID id) {
        var rows = jdbc.queryForList("""
            SELECT id,order_id AS "orderId",requested_by AS "requestedBy",status,
              input_data::text AS "inputData",generated_diagnosis AS "originalResponse",
              result_data::text AS "resultJson",error_message AS "errorMessage"
            FROM ai_prediagnoses WHERE id=?
            """, id);
        return rows.isEmpty() ? null : rows.getFirst();
    }

    public String orderStatus(UUID orderId) {
        var rows = jdbc.queryForList("SELECT status_code FROM service_orders WHERE id=?", orderId);
        return rows.isEmpty() ? null : (String) rows.getFirst().get("status_code");
    }
}
