package com.clinicainformatica.api;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class SprintFiveRepository {
    private final JdbcTemplate jdbc;

    public SprintFiveRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Map<String, Object> equipmentHistory(UUID equipmentId, String status,
        LocalDate from, LocalDate to) {
        List<Map<String, Object>> equipment = jdbc.queryForList("""
            SELECT e.id::text AS id,e.type,e.brand,e.model,e.serial_number AS "serialNumber",
              e.characteristics,e.accessories,e.observations,c.id::text AS "clientId",
              c.document_type || ' ' || c.document_number AS "clientDocument",
              btrim(c.first_name || ' ' || c.last_name) AS "ownerName"
            FROM equipment e JOIN clients c ON c.id=e.client_id
            WHERE e.id=?
            """, equipmentId);
        if (equipment.isEmpty()) {
            return null;
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("equipment", equipment.getFirst());
        result.put("orders", equipmentOrders(equipmentId, status, from, to));
        return result;
    }

    private List<Map<String, Object>> equipmentOrders(UUID equipmentId, String status,
        LocalDate from, LocalDate to) {
        return jdbc.queryForList("""
            SELECT so.id::text AS id,'OS-' || lpad(so.number::text,6,'0') AS code,
              so.received_at::text AS "receivedDate",so.created_at::text AS "createdAt",
              so.status_code AS status,
              CASE so.priority WHEN 'NORMAL' THEN 'MEDIA' ELSE so.priority END AS priority,
              so.reported_problem AS "reportedProblem",
              so.finalized_at::text AS "finalizedAt",
              current_technician.id::text AS "technicianId",
              CASE WHEN current_technician.id IS NULL THEN NULL
                ELSE btrim(current_technician.first_name || ' ' || current_technician.last_name)
              END AS "technicianName",
              attention.diagnosis,attention.actions_performed AS "actionsPerformed",
              attention.performed_tests AS "performedTests",
              attention.result_summary AS "resultSummary",
              attention.finished_at::text AS "attentionFinishedAt",
              prediction.generated_diagnosis AS "aiOriginalResponse",
              prediction.result_data::text AS "aiResult",
              prediction.decision AS "aiValidation",
              prediction.modified_data::text AS "aiModifiedResult",
              prediction.observations AS "aiValidationObservations",
              prediction.validated_at::text AS "aiValidatedAt"
            FROM service_orders so
            LEFT JOIN LATERAL (
              SELECT u.id,u.first_name,u.last_name
              FROM technician_assignments ta JOIN users u ON u.id=ta.technician_id
              WHERE ta.order_id=so.id
              ORDER BY ta.assigned_at DESC,ta.id DESC LIMIT 1
            ) current_technician ON true
            LEFT JOIN LATERAL (
              SELECT a.diagnosis,a.actions_performed,a.performed_tests,a.result_summary,a.finished_at
              FROM technical_attentions a
              WHERE a.order_id=so.id
              ORDER BY a.updated_at DESC,a.id DESC LIMIT 1
            ) attention ON true
            LEFT JOIN LATERAL (
              SELECT p.generated_diagnosis,p.result_data,v.decision,v.modified_data,
                v.observations,v.validated_at
              FROM ai_prediagnoses p JOIN ai_validations v ON v.prediagnosis_id=p.id
              WHERE p.order_id=so.id AND p.status='GENERADO'
              ORDER BY v.validated_at DESC,v.id DESC LIMIT 1
            ) prediction ON true
            WHERE so.equipment_id=?
              AND (? = '' OR so.status_code=?)
              AND (?::date IS NULL OR so.received_at::date>=?::date)
              AND (?::date IS NULL OR so.received_at::date<=?::date)
            ORDER BY GREATEST(
              so.created_at,
              COALESCE((SELECT max(a.updated_at) FROM technical_attentions a
                WHERE a.order_id=so.id),so.created_at)
            ) DESC,so.number DESC
            """, equipmentId, status, status, from, from, to, to);
    }

    public List<Map<String, Object>> trackingOrders(String search, String status, UUID technicianId) {
        String term = "%" + search.trim().toLowerCase(java.util.Locale.ROOT) + "%";
        return jdbc.queryForList("""
            SELECT so.id::text AS id,'OS-' || lpad(so.number::text,6,'0') AS code,
              so.received_at::text AS "receivedDate",so.status_code AS status,
              btrim(c.first_name || ' ' || c.last_name) AS "clientName",
              e.id::text AS "equipmentId",e.type AS "equipmentType",e.brand,e.model,
              latest_technician.id::text AS "technicianId",
              CASE WHEN latest_technician.id IS NULL THEN NULL
                ELSE btrim(latest_technician.first_name || ' ' || latest_technician.last_name)
              END AS "technicianName"
            FROM service_orders so
            JOIN clients c ON c.id=so.client_id
            JOIN equipment e ON e.id=so.equipment_id
            LEFT JOIN LATERAL (
              SELECT u.id,u.first_name,u.last_name
              FROM technician_assignments ta JOIN users u ON u.id=ta.technician_id
              WHERE ta.order_id=so.id
              ORDER BY ta.assigned_at DESC,ta.id DESC LIMIT 1
            ) latest_technician ON true
            WHERE (? = '' OR lower(so.number::text) LIKE ?
              OR lower('OS-' || lpad(so.number::text,6,'0')) LIKE ?
              OR lower(c.first_name || ' ' || c.last_name) LIKE ?
              OR lower(e.type || ' ' || e.brand || ' ' || e.model) LIKE ?)
              AND (? = '' OR so.status_code=?)
              AND (?::uuid IS NULL OR EXISTS (
                SELECT 1 FROM technician_assignments mine
                WHERE mine.order_id=so.id AND mine.technician_id=?::uuid AND mine.ended_at IS NULL
              ))
            ORDER BY so.received_at DESC,so.number DESC
            """, search.trim(), term, term, term, term, status, status, technicianId, technicianId);
    }

    public Map<String, Object> trackingDetail(UUID orderId, UUID technicianId) {
        List<Map<String, Object>> orders = jdbc.queryForList("""
            SELECT so.id::text AS id,'OS-' || lpad(so.number::text,6,'0') AS code,
              so.received_at::text AS "receivedDate",so.created_at::text AS "createdAt",
              so.status_code AS status,
              CASE so.priority WHEN 'NORMAL' THEN 'MEDIA' ELSE so.priority END AS priority,
              so.reported_problem AS "reportedProblem",
              so.finalized_at::text AS "finalizedAt",e.id::text AS "equipmentId",
              e.type AS "equipmentType",e.brand,e.model,e.serial_number AS "serialNumber",
              current_technician.id::text AS "technicianId",
              CASE WHEN current_technician.id IS NULL THEN NULL
                ELSE btrim(current_technician.first_name || ' ' || current_technician.last_name)
              END AS "technicianName",
              current_assignment.assigned_at::text AS "assignedAt",
              attention.diagnosis,attention.actions_performed AS "actionsPerformed",
              attention.performed_tests AS "performedTests",
              attention.result_summary AS "resultSummary",
              attention.finished_at::text AS "attentionFinishedAt"
            FROM service_orders so JOIN equipment e ON e.id=so.equipment_id
            LEFT JOIN LATERAL (
              SELECT u.id,u.first_name,u.last_name
              FROM technician_assignments ta JOIN users u ON u.id=ta.technician_id
              WHERE ta.order_id=so.id
              ORDER BY ta.assigned_at DESC,ta.id DESC LIMIT 1
            ) current_technician ON true
            LEFT JOIN LATERAL (
              SELECT ta.assigned_at FROM technician_assignments ta
              WHERE ta.order_id=so.id
              ORDER BY ta.assigned_at DESC,ta.id DESC LIMIT 1
            ) current_assignment ON true
            LEFT JOIN LATERAL (
              SELECT a.diagnosis,a.actions_performed,a.performed_tests,a.result_summary,a.finished_at
              FROM technical_attentions a
              WHERE a.order_id=so.id
              ORDER BY a.updated_at DESC,a.id DESC LIMIT 1
            ) attention ON true
            WHERE so.id=? AND (?::uuid IS NULL OR EXISTS (
              SELECT 1 FROM technician_assignments mine
              WHERE mine.order_id=so.id AND mine.technician_id=?::uuid AND mine.ended_at IS NULL
            ))
            """, orderId, technicianId, technicianId);
        if (orders.isEmpty()) {
            return null;
        }
        Map<String, Object> order = orders.getFirst();
        order.put("timeline", timeline(orderId));
        order.put("validatedPrediagnoses", jdbc.queryForList("""
            SELECT p.generated_diagnosis AS "originalResponse",
              p.result_data::text AS "originalResult",v.decision,
              v.modified_data::text AS "modifiedResult",v.observations,
              v.validated_at::text AS "validatedAt",
              btrim(u.first_name || ' ' || u.last_name) AS "validatedBy"
            FROM ai_validations v
            JOIN ai_prediagnoses p ON p.id=v.prediagnosis_id
            JOIN users u ON u.id=v.technician_id
            WHERE p.order_id=? AND p.status='GENERADO'
            ORDER BY v.validated_at DESC,v.id DESC
            """, orderId));
        return order;
    }

    public Map<String, Object> publicTracking(String code, String phone) {
        List<Map<String, Object>> orders = jdbc.queryForList("""
            SELECT so.id,'OS-' || lpad(so.number::text,6,'0') AS code,
              e.type AS "equipmentType",so.received_at::text AS "receivedDate",
              so.created_at::text AS "createdAt",so.status_code AS status,
              so.finalized_at::text AS "finalizedAt"
            FROM service_orders so
            JOIN clients c ON c.id=so.client_id
            JOIN equipment e ON e.id=so.equipment_id
            WHERE upper('OS-' || lpad(so.number::text,6,'0'))=upper(?)
              AND regexp_replace(c.phone,'[^0-9]','','g')=?
            """, code.trim(), phone.replaceAll("[^0-9]", ""));
        if (orders.isEmpty()) {
            return null;
        }
        Map<String, Object> order = orders.getFirst();
        UUID id = (UUID) order.remove("id");
        order.put("timeline", timeline(id));
        return order;
    }

    private List<Map<String, Object>> timeline(UUID orderId) {
        Map<String, Object> dates = jdbc.queryForMap("""
            SELECT so.created_at::text AS "registeredAt",
              (SELECT min(ta.assigned_at)::text FROM technician_assignments ta
               WHERE ta.order_id=so.id) AS "assignedAt",
              (SELECT min(h.changed_at)::text FROM order_status_history h
               WHERE h.order_id=so.id AND h.to_status='EN_ATENCION') AS "attentionAt",
              COALESCE(so.finalized_at::text,
                (SELECT min(h.changed_at)::text FROM order_status_history h
                 WHERE h.order_id=so.id AND h.to_status='FINALIZADA')) AS "finalizedAt"
            FROM service_orders so WHERE so.id=?
            """, orderId);
        return List.of(
            timelineStep("ORDEN_REGISTRADA", "Orden registrada", dates.get("registeredAt")),
            timelineStep("TECNICO_ASIGNADO", "Técnico asignado", dates.get("assignedAt")),
            timelineStep("EN_ATENCION", "Servicio en atención", dates.get("attentionAt")),
            timelineStep("FINALIZADA", "Servicio finalizado", dates.get("finalizedAt"))
        );
    }

    private Map<String, Object> timelineStep(String code, String label, Object occurredAt) {
        Map<String, Object> step = new LinkedHashMap<>();
        step.put("code", code);
        step.put("label", label);
        step.put("occurredAt", occurredAt);
        step.put("completed", occurredAt != null);
        return step;
    }
}
