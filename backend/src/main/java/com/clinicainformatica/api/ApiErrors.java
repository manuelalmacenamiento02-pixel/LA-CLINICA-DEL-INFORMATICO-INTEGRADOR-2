package com.clinicainformatica.api;

import java.util.Map;
import jakarta.validation.ConstraintViolationException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ApiErrors {
    @ExceptionHandler(ApiException.class)
    ResponseEntity<?> api(ApiException e) {
        return ResponseEntity.status(e.status).body(Map.of("code", e.code, "message", e.getMessage()));
    }
    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<?> invalid(MethodArgumentNotValidException e) {
        return ResponseEntity.badRequest().body(Map.of("code", "invalid-data", "message", "Revisa los campos obligatorios y sus formatos."));
    }
    @ExceptionHandler(ConstraintViolationException.class)
    ResponseEntity<?> constraint(ConstraintViolationException e) {
        return ResponseEntity.badRequest().body(Map.of("code", "invalid-data", "message", "Revisa los parámetros de la solicitud."));
    }
    @ExceptionHandler(DataIntegrityViolationException.class)
    ResponseEntity<?> integrity(DataIntegrityViolationException e) {
        String detail = e.getMostSpecificCause().getMessage();
        String code = "related-records";
        if (detail != null && detail.contains("clients_document_unique")) code = "duplicate-document";
        else if (detail != null && detail.contains("clients_email_unique")) code = "duplicate-email";
        else if (detail != null && detail.contains("equipment_serial_unique")) code = "duplicate-serial";
        else if (detail != null && detail.contains("users_username_unique")) code = "duplicate-username";
        else if (detail != null && detail.contains("service_orders_number_key")) code = "duplicate-order-code";
        else if (detail != null && detail.contains("check constraint")) code = "invalid-data";
        return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of("code", code,
            "message", "No se pudo guardar: hay datos duplicados, inválidos o registros relacionados."));
    }
    @ExceptionHandler(IllegalArgumentException.class)
    ResponseEntity<?> badRequest(IllegalArgumentException e) {
        return ResponseEntity.badRequest().body(Map.of("code", "invalid-data", "message", "Datos no válidos."));
    }
}
