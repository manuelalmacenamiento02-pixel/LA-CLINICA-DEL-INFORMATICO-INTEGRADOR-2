package com.clinicainformatica.api;

import java.net.*;
import java.net.http.*;
import java.time.LocalDate;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.dao.DataIntegrityViolationException;
import static org.junit.jupiter.api.Assertions.*;

// Run only against an explicitly supplied, disposable PostgreSQL database.
@SpringBootTest(webEnvironment=SpringBootTest.WebEnvironment.RANDOM_PORT, properties={"debug=false", "logging.level.root=WARN"})
@EnabledIfEnvironmentVariable(named="DB_TEST_URL",matches=".*[/]clinica_test.*")
class ClinicaApiApplicationTests {
    @LocalServerPort int port;
    @Autowired JdbcTemplate jdbc;
    static final String PASSWORD = "test-admin-strong-password";
    @DynamicPropertySource static void config(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url",() -> System.getenv("DB_TEST_URL"));
        r.add("spring.datasource.username",() -> Optional.ofNullable(System.getenv("DB_TEST_USER")).orElse("clinic_test"));
        r.add("spring.datasource.password",() -> Optional.ofNullable(System.getenv("DB_TEST_PASSWORD")).orElse(""));
        r.add("clinica.bootstrap.username",() -> "admin");
        r.add("clinica.bootstrap.password",() -> PASSWORD);
    }
    HttpClient client() {return HttpClient.newBuilder().cookieHandler(new CookieManager(null,CookiePolicy.ACCEPT_ALL)).build();}
    HttpResponse<String> call(HttpClient c,String method,String path,String body,boolean csrf) throws Exception {
        var builder=HttpRequest.newBuilder(URI.create("http://localhost:"+port+"/api"+path));
        if(csrf) builder.header("X-Requested-With","XMLHttpRequest");
        if(body != null) builder.header("Content-Type","application/json");
        return c.send(builder.method(method,body == null?HttpRequest.BodyPublishers.noBody():HttpRequest.BodyPublishers.ofString(body)).build(),HttpResponse.BodyHandlers.ofString());
    }
    @Test void migrationsConstraintsAndProtectedApi() throws Exception {
        assertEquals(18,jdbc.queryForObject("SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' AND table_name <> 'flyway_schema_history'",Integer.class));
        assertEquals(6,jdbc.queryForObject("SELECT count(*) FROM flyway_schema_history WHERE success",Integer.class));
        var admin=client();
        assertEquals(401,call(admin,"GET","/clients",null,true).statusCode());
        String login="{\"username\":\"admin\",\"password\":\""+PASSWORD+"\"}";
        assertEquals(403,call(admin,"POST","/auth/login",login,false).statusCode());
        assertEquals(200,call(admin,"POST","/auth/login",login,true).statusCode());
        assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM system_events WHERE event_type='LOGIN' AND result='SUCCESS'",Integer.class));
        var failedLogin=client();
        assertEquals(401,call(failedLogin,"POST","/auth/login","{\"username\":\"missing\",\"password\":\"incorrect-password\"}",true).statusCode());
        assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM system_events WHERE event_type='LOGIN_FAILED' AND result='FAILED'",Integer.class));
        assertEquals(200,call(admin,"GET","/indicators/dashboard",null,true).statusCode());
        assertEquals(200,call(admin,"GET","/admin/audit",null,true).statusCode());
        assertEquals(200,call(admin,"GET","/admin/backups",null,true).statusCode());
        assertEquals(200,call(admin,"GET","/admin/monitoring",null,true).statusCode());
        var snapshot=call(admin,"GET","/bootstrap",null,true);
        assertEquals(200,snapshot.statusCode());assertFalse(snapshot.body().contains("password"));
        String clientBody="{\"documentType\":\"DNI\",\"documentNumber\":\"40123456\",\"firstName\":\"Elena\",\"lastName\":\"Vega\",\"phone\":\"987123456\",\"email\":\"\",\"address\":\"\",\"observations\":\"\"}";
        assertEquals(200,call(admin,"POST","/clients",clientBody,true).statusCode());
        UUID clientId=jdbc.queryForObject("SELECT id FROM clients WHERE document_number='40123456'",UUID.class);
        var duplicate=call(admin,"POST","/clients",clientBody,true);
        assertEquals(409,duplicate.statusCode());assertTrue(duplicate.body().contains("duplicate-document"));
        assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM clients WHERE lower(document_number)=lower(?)",Integer.class,"40123456"));
        var invalid=call(admin,"POST","/clients",clientBody.replace("40123456","short"),true);
        assertEquals(409,invalid.statusCode());
        String equipment="{\"clientId\":\""+clientId+"\",\"type\":\"Laptop\",\"brand\":\"Lenovo\",\"model\":\"E14\",\"serialNumber\":\"SN-1\",\"characteristics\":\"\",\"accessories\":\"\",\"observations\":\"\"}";
        assertEquals(200,call(admin,"POST","/equipment",equipment,true).statusCode());
        UUID equipmentId=jdbc.queryForObject("SELECT id FROM equipment WHERE serial_number='SN-1'",UUID.class);
        assertEquals(409,call(admin,"POST","/equipment",equipment.replace("SN-1","sn-1"),true).statusCode());
        assertEquals(409,call(admin,"DELETE","/clients/"+clientId,null,true).statusCode());
        assertEquals(200,call(admin,"PUT","/clients/"+clientId,clientBody.replace("Elena","Elena Maria"),true).statusCode());
        assertEquals("Elena Maria",jdbc.queryForObject("SELECT first_name FROM clients WHERE id=?",String.class,clientId));
        String technician="{\"firstName\":\"Pedro\",\"lastName\":\"Ruiz\",\"username\":\"pruiz\",\"password\":\"test-tech-password\",\"role\":\"TÉCNICO\",\"active\":true}";
        assertEquals(200,call(admin,"POST","/users",technician,true).statusCode());
        String stored=jdbc.queryForObject("SELECT password_hash FROM users WHERE username='pruiz'",String.class);
        assertNotEquals("test-tech-password",stored);assertTrue(stored.startsWith("$2"));
        var tech=client();
        assertEquals(200,call(tech,"POST","/auth/login","{\"username\":\"pruiz\",\"password\":\"test-tech-password\"}",true).statusCode());
        assertEquals(403,call(tech,"GET","/clients",null,true).statusCode());
        assertEquals(403,call(tech,"GET","/admin/audit",null,true).statusCode());
        assertEquals(403,call(tech,"GET","/%63lients",null,true).statusCode());
        assertEquals(403,call(tech,"POST","/clients",clientBody,true).statusCode());
        assertEquals(200,call(admin,"PUT","/permissions","{\"role\":\"TÉCNICO\",\"permission\":\"clients\",\"allowed\":true}",true).statusCode());
        assertEquals(200,call(tech,"GET","/clients",null,true).statusCode());
        UUID techId=jdbc.queryForObject("SELECT id FROM users WHERE username='pruiz'",UUID.class);
        assertEquals(200,call(admin,"PATCH","/users/"+techId+"/active","{\"active\":false}",true).statusCode());
        assertEquals(401,call(tech,"GET","/clients",null,true).statusCode());
        UUID adminId=jdbc.queryForObject("SELECT id FROM users WHERE username='admin'",UUID.class);
        assertEquals(409,call(admin,"PATCH","/users/"+adminId+"/active","{\"active\":false}",true).statusCode());
        assertEquals(400,call(admin,"PUT","/permissions","{\"role\":\"TÉCNICO\",\"permission\":\"users\",\"allowed\":true}",true).statusCode());
        UUID order=UUID.randomUUID();
        jdbc.update("INSERT INTO service_orders(id,equipment_id,client_id,received_by,reported_problem) VALUES (?,?,?,?,?)",order,equipmentId,clientId,adminId,"No enciende");
        assertThrows(DataIntegrityViolationException.class,() -> jdbc.update("UPDATE service_orders SET status_code='FINALIZADA' WHERE id=?",order));
        assertThrows(DataIntegrityViolationException.class,() -> jdbc.update("INSERT INTO technician_assignments(order_id,technician_id,assigned_by) VALUES (?,?,?)",order,adminId,adminId));
        assertEquals(400,call(admin,"POST","/orders/"+order+"/assignment",
            "{\"technicianId\":\""+techId+"\",\"notes\":\"\"}",true).statusCode());
        assertEquals(400,call(admin,"POST","/orders/"+order+"/assignment",
            "{\"technicianId\":\""+adminId+"\",\"notes\":\"\"}",true).statusCode());
        jdbc.update("UPDATE users SET active=true WHERE id=?",techId);
        jdbc.update("INSERT INTO technician_assignments(order_id,technician_id,assigned_by) VALUES (?,?,?)",order,techId,adminId);
        assertThrows(DataIntegrityViolationException.class,() -> jdbc.update("INSERT INTO technician_assignments(order_id,technician_id,assigned_by) VALUES (?,?,?)",order,techId,adminId));
        var technicianBootstrap=call(tech,"GET","/bootstrap",null,true);
        assertEquals(200,technicianBootstrap.statusCode());
        assertTrue(technicianBootstrap.body().contains(order.toString()));
        assertTrue(technicianBootstrap.body().contains("\"priority\":\"NORMAL\""));
        String newOrderBody="{\"clientId\":\""+clientId+"\",\"equipmentId\":\""+equipmentId
            +"\",\"receivedDate\":\""+LocalDate.now()+"\",\"reportedProblem\":\"No inicia\","
            +"\"initialObservations\":\"Equipo recibido con cargador\",\"priority\":\"MEDIA\"}";
        var createdOrder=call(admin,"POST","/orders",newOrderBody,true);
        assertEquals(200,createdOrder.statusCode());assertTrue(createdOrder.body().contains("\"code\":\"OS-"));
        UUID createdOrderId=UUID.fromString(createdOrder.body().replaceFirst("(?s).*\\\"id\\\":\\\"([^\\\"]+)\\\".*","$1"));
        assertEquals(1,call(admin,"GET","/orders?q=OS-",null,true).body().split(createdOrderId.toString(),-1).length-1);
        assertEquals(LocalDate.now(),jdbc.queryForObject("SELECT received_at FROM service_orders WHERE id=?",java.time.LocalDate.class,createdOrderId));
        assertTrue(call(admin,"GET","/orders/technicians",null,true).body().contains(techId.toString()));
        String updatedOrderBody=newOrderBody.replace("No inicia","Se reinicia").replace("\"MEDIA\"","\"ALTA\"");
        assertEquals(200,call(admin,"PUT","/orders/"+createdOrderId,updatedOrderBody,true).statusCode());
        assertEquals("Se reinicia",jdbc.queryForObject("SELECT reported_problem FROM service_orders WHERE id=?",String.class,createdOrderId));
        String assignment="{\"technicianId\":\""+techId+"\",\"notes\":\"Asignación de prueba\"}";
        assertEquals(200,call(admin,"POST","/orders/"+createdOrderId+"/assignment",assignment,true).statusCode());
        assertEquals(200,call(admin,"POST","/orders/"+createdOrderId+"/assignment",assignment,true).statusCode());
        assertEquals(1,jdbc.queryForObject("SELECT count(*) FROM technician_assignments WHERE order_id=? AND ended_at IS NULL",Integer.class,createdOrderId));
        assertEquals(2,jdbc.queryForObject("SELECT count(*) FROM technician_assignments WHERE order_id=?",Integer.class,createdOrderId));
        var ownOrders=call(tech,"GET","/orders/mine",null,true);
        assertEquals(200,ownOrders.statusCode());assertTrue(ownOrders.body().contains(createdOrderId.toString()));
        assertTrue(call(tech,"GET","/orders",null,true).body().contains(createdOrderId.toString()));
        String unassignedBody=newOrderBody.replace("No inicia","Otro problema");
        var otherOrder=call(admin,"POST","/orders",unassignedBody,true);
        UUID otherOrderId=UUID.fromString(otherOrder.body().replaceFirst("(?s).*\\\"id\\\":\\\"([^\\\"]+)\\\".*","$1"));
        assertFalse(call(tech,"GET","/orders",null,true).body().contains(otherOrderId.toString()));
        assertEquals(404,call(tech,"GET","/orders/"+otherOrderId,null,true).statusCode());
        assertEquals(200,call(tech,"PATCH","/orders/"+createdOrderId+"/status",
            "{\"status\":\"EN_ATENCION\",\"reason\":\"Inicio de trabajo\"}",true).statusCode());
        assertEquals("EN_ATENCION",jdbc.queryForObject("SELECT status_code FROM service_orders WHERE id=?",String.class,createdOrderId));
        assertEquals(409,call(tech,"PATCH","/orders/"+createdOrderId+"/status",
            "{\"status\":\"FINALIZADA\",\"reason\":\"Intento sin diagnóstico\"}",true).statusCode());
        var orderDetail=call(tech,"GET","/orders/"+createdOrderId,null,true);
        assertEquals(200,orderDetail.statusCode());assertTrue(orderDetail.body().contains("\"toStatus\":\"EN_ATENCION\""));
        assertEquals(409,call(admin,"DELETE","/equipment/"+equipmentId,null,true).statusCode());
        assertTrue(jdbc.queryForObject("SELECT count(*) FROM system_events",Integer.class) >= 8);
        assertEquals(200,call(admin,"POST","/auth/logout",null,true).statusCode());
        assertEquals(401,call(admin,"GET","/bootstrap",null,true).statusCode());
        var secondSession=client();
        assertEquals(200,call(secondSession,"POST","/auth/login",login,true).statusCode());
        assertTrue(call(secondSession,"GET","/bootstrap",null,true).body().contains("Elena Maria"));
    }
}
