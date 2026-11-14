package com.clinicainformatica.api;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class ClinicRepository {
    private final JdbcTemplate jdbc;
    public ClinicRepository(JdbcTemplate jdbc) { this.jdbc = jdbc; }
    public JdbcTemplate jdbc() { return jdbc; }
    public Map<String,Object> user(UUID id) {
        var rows = jdbc.query("SELECT id,first_name,last_name,username,role_code,active FROM users WHERE id=?", this::userRow, id);
        return rows.isEmpty() ? null : rows.getFirst();
    }
    Map<String,Object> userRow(ResultSet rs, int row) throws SQLException {
        return Map.of("id",rs.getString("id"),"firstName",rs.getString("first_name"),"lastName",rs.getString("last_name"),
            "username",rs.getString("username"),"role",rs.getString("role_code"),"active",rs.getBoolean("active"));
    }
    List<Map<String,Object>> users() { return jdbc.query("SELECT * FROM users ORDER BY created_at,id",this::userRow); }
    public Map<String,List<String>> permissions() {
        Map<String,List<String>> result = new LinkedHashMap<>();
        jdbc.query("SELECT code FROM roles ORDER BY code", (org.springframework.jdbc.core.RowCallbackHandler) rs -> result.put(rs.getString(1),new ArrayList<>()));
        jdbc.query("SELECT role_code,permission_code FROM role_permissions ORDER BY role_code,permission_code",
            (org.springframework.jdbc.core.RowCallbackHandler) rs -> result.get(rs.getString(1)).add(rs.getString(2)));
        return result;
    }
    boolean can(String role,String permission) {
        return Boolean.TRUE.equals(jdbc.queryForObject("SELECT EXISTS(SELECT 1 FROM role_permissions WHERE role_code=? AND permission_code=?)",Boolean.class,role,permission));
    }
    Map<String,Object> clientRow(ResultSet rs,int row) throws SQLException {
        Map<String,Object> c=new LinkedHashMap<>();
        c.put("id",rs.getString("id"));
        String[][] fields={{"documentType","document_type"},{"documentNumber","document_number"},{"firstName","first_name"},
          {"lastName","last_name"},{"phone","phone"},{"email","email"},{"address","address"},{"observations","observations"}};
        for(var f:fields) c.put(f[0],rs.getString(f[1]));
        return c;
    }
    List<Map<String,Object>> clients() {return jdbc.query("SELECT * FROM clients ORDER BY created_at,id",this::clientRow);}
    Map<String,Object> equipmentRow(ResultSet rs,int row) throws SQLException {
        Map<String,Object> e=new LinkedHashMap<>();
        e.put("id",rs.getString("id"));
        String[][] fields={{"clientId","client_id"},{"type","type"},{"brand","brand"},{"model","model"},{"serialNumber","serial_number"},
          {"characteristics","characteristics"},{"accessories","accessories"},{"observations","observations"}};
        for(var f:fields) e.put(f[0],rs.getString(f[1]));
        return e;
    }
    List<Map<String,Object>> equipment() {return jdbc.query("SELECT * FROM equipment ORDER BY created_at,id",this::equipmentRow);}
    List<Map<String,Object>> technicianOrders(UUID technicianId) {
        return jdbc.queryForList("""
            SELECT so.id,so.number AS "orderNumber",so.priority,so.status_code AS status,
              so.reported_problem AS "reportedProblem",e.type AS "equipmentType",e.brand,e.model,
              e.serial_number AS "serialNumber",btrim(c.first_name || ' ' || c.last_name) AS "clientName"
            FROM technician_assignments ta
            JOIN service_orders so ON so.id=ta.order_id
            JOIN equipment e ON e.id=so.equipment_id
            JOIN clients c ON c.id=so.client_id
            WHERE ta.technician_id=? AND ta.ended_at IS NULL
              AND so.status_code NOT IN ('CERRADA','CANCELADA')
            ORDER BY CASE so.priority
              WHEN 'URGENTE' THEN 0 WHEN 'ALTA' THEN 1 WHEN 'NORMAL' THEN 2 ELSE 3 END,
              so.created_at,so.number
            """,technicianId);
    }
    List<Map<String,Object>> serviceOrders(String search,String status,UUID technicianId) {
        String term = "%" + search.trim().toLowerCase(Locale.ROOT) + "%";
        return jdbc.queryForList("""
            SELECT so.id::text AS id,'OS-' || lpad(so.number::text,6,'0') AS code,so.number AS "orderNumber",
              so.received_at::text AS "receivedDate",so.created_at::text AS "createdAt",so.status_code AS status,
              CASE so.priority WHEN 'NORMAL' THEN 'MEDIA' ELSE so.priority END AS priority,
              so.reported_problem AS "reportedProblem",so.intake_condition AS "initialObservations",
              c.id::text AS "clientId",btrim(c.first_name || ' ' || c.last_name) AS "clientName",
              c.document_type || ' ' || c.document_number AS "clientDocument",c.phone AS "clientPhone",
              e.id::text AS "equipmentId",e.type AS "equipmentType",e.brand,e.model,
              e.serial_number AS "serialNumber",e.characteristics AS "equipmentCharacteristics",
              u.id::text AS "technicianId",
              CASE WHEN u.id IS NULL THEN NULL ELSE btrim(u.first_name || ' ' || u.last_name) END AS "technicianName"
            FROM service_orders so
            JOIN clients c ON c.id=so.client_id
            JOIN equipment e ON e.id=so.equipment_id
            LEFT JOIN LATERAL (
              SELECT assigned_user.id,assigned_user.first_name,assigned_user.last_name
              FROM technician_assignments ta
              JOIN users assigned_user ON assigned_user.id=ta.technician_id
              WHERE ta.order_id=so.id AND ta.ended_at IS NULL
              LIMIT 1
            ) u ON true
            WHERE (? = '' OR lower(so.number::text) LIKE ? OR lower('OS-' || lpad(so.number::text,6,'0')) LIKE ?
              OR lower(c.first_name || ' ' || c.last_name) LIKE ?
              OR lower(e.type || ' ' || e.brand || ' ' || e.model || ' ' || e.serial_number) LIKE ?)
              AND (? = '' OR so.status_code = ?)
              AND (?::uuid IS NULL OR EXISTS (
                SELECT 1 FROM technician_assignments mine
                WHERE mine.order_id=so.id AND mine.technician_id=?::uuid AND mine.ended_at IS NULL
              ))
            ORDER BY so.received_at DESC,so.number DESC
            """,search.trim(),term,term,term,term,status, status,technicianId,technicianId);
    }
    Map<String,Object> serviceOrder(UUID id,UUID technicianId) {
        var rows = jdbc.queryForList("""
            SELECT so.id::text AS id,'OS-' || lpad(so.number::text,6,'0') AS code,so.number AS "orderNumber",
              so.received_at::text AS "receivedDate",so.created_at::text AS "createdAt",so.status_code AS status,
              CASE so.priority WHEN 'NORMAL' THEN 'MEDIA' ELSE so.priority END AS priority,
              so.reported_problem AS "reportedProblem",so.intake_condition AS "initialObservations",
              c.id::text AS "clientId",btrim(c.first_name || ' ' || c.last_name) AS "clientName",
              c.document_type || ' ' || c.document_number AS "clientDocument",c.phone AS "clientPhone",
              e.id::text AS "equipmentId",e.type AS "equipmentType",e.brand,e.model,
              e.serial_number AS "serialNumber",e.characteristics AS "equipmentCharacteristics",
              u.id::text AS "technicianId",
              CASE WHEN u.id IS NULL THEN NULL ELSE btrim(u.first_name || ' ' || u.last_name) END AS "technicianName"
            FROM service_orders so
            JOIN clients c ON c.id=so.client_id
            JOIN equipment e ON e.id=so.equipment_id
            LEFT JOIN LATERAL (
              SELECT assigned_user.id,assigned_user.first_name,assigned_user.last_name
              FROM technician_assignments ta
              JOIN users assigned_user ON assigned_user.id=ta.technician_id
              WHERE ta.order_id=so.id AND ta.ended_at IS NULL
              LIMIT 1
            ) u ON true
            WHERE so.id=? AND (?::uuid IS NULL OR EXISTS (
              SELECT 1 FROM technician_assignments mine
              WHERE mine.order_id=so.id AND mine.technician_id=?::uuid AND mine.ended_at IS NULL
            ))
            """,id,technicianId,technicianId);
        if (rows.isEmpty()) return null;
        Map<String,Object> order = rows.getFirst();
        order.put("history", statusHistory(id));
        return order;
    }
    List<Map<String,Object>> statusHistory(UUID orderId) {
        return jdbc.queryForList("""
            SELECT h.from_status AS "fromStatus",h.to_status AS "toStatus",h.reason,
              h.changed_at::text AS "changedAt",btrim(u.first_name || ' ' || u.last_name) AS "changedBy"
            FROM order_status_history h JOIN users u ON u.id=h.changed_by
            WHERE h.order_id=? ORDER BY h.changed_at,h.id
            """,orderId);
    }
    List<Map<String,Object>> activeTechnicians() {
        return jdbc.queryForList("""
            SELECT id::text AS id,first_name AS "firstName",last_name AS "lastName",username
            FROM users WHERE active AND role_code='TÉCNICO'
            ORDER BY first_name,last_name,id
            """);
    }
    void audit(UUID actor,String type,String entity,UUID id) {
        audit(actor,type,entity,id,"SUCCESS",type.replace('_',' ').toLowerCase(Locale.ROOT));
    }
    void audit(UUID actor,String type,String entity,UUID id,String result,String description) {
        jdbc.update("""
            INSERT INTO system_events(actor_id,event_type,entity_type,entity_id,result,description)
            VALUES (?,?,?,?,?,?)
            """,actor,type,entity,id,result,description);
    }
}
