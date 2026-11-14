package com.clinicainformatica.api;

import java.util.Map;
import java.util.UUID;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/prediagnoses")
public class PrediagnosisValidationController {
    private final PrediagnosisService service;

    public PrediagnosisValidationController(PrediagnosisService service) {
        this.service = service;
    }

    @PatchMapping("/{id}/validation")
    public Map<String, Object> validate(@PathVariable UUID id,
        @Valid @RequestBody PrediagnosisValidationDraft draft, HttpServletRequest request) {
        Map<String, Object> actor = actor(request);
        return service.validateRequest(id, UUID.fromString((String) actor.get("id")), actor, draft);
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> actor(HttpServletRequest request) {
        Object currentUser = request.getAttribute("currentUser");
        if (!(currentUser instanceof Map<?, ?>)) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "unauthorized",
                "Inicia sesión para continuar.");
        }
        return (Map<String, Object>) currentUser;
    }
}
