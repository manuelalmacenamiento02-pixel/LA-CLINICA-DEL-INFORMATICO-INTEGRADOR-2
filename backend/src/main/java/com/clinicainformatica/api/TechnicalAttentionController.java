package com.clinicainformatica.api;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/orders")
public class TechnicalAttentionController {
    private final TechnicalAttentionService attentionService;
    private final PrediagnosisService prediagnosisService;

    public TechnicalAttentionController(TechnicalAttentionService attentionService,
        PrediagnosisService prediagnosisService) {
        this.attentionService = attentionService;
        this.prediagnosisService = prediagnosisService;
    }

    public record PrediagnosisRequest(
        @NotNull @Size(max = 5000) String additionalSymptoms,
        @NotNull @Size(max = 5000) String observations
    ) {}

    @GetMapping("/{id}/attention")
    public Map<String, Object> attention(@PathVariable UUID id, HttpServletRequest request) {
        Map<String, Object> result = attentionService.attention(id, actor(request));
        return result == null ? Map.of() : result;
    }

    @PutMapping("/{id}/attention")
    public Map<String, Object> saveAttention(@PathVariable UUID id,
        @Valid @RequestBody TechnicalAttentionDraft draft, HttpServletRequest request) {
        return attentionService.save(id, actorId(request), actor(request), draft.attendedAt(),
            draft.diagnosis(), draft.actionsPerformed(), draft.performedTests(), draft.partsUsed(),
            draft.observations(), draft.resultSummary());
    }

    @PostMapping("/{id}/finalize")
    public Map<String, Object> finalizeOrder(@PathVariable UUID id, HttpServletRequest request) {
        return attentionService.finalizeOrder(id, actorId(request), actor(request));
    }

    @GetMapping("/{id}/prediagnoses")
    public List<Map<String, Object>> prediagnoses(@PathVariable UUID id, HttpServletRequest request) {
        return prediagnosisService.list(id, actor(request));
    }

    @PostMapping("/{id}/prediagnoses")
    public Map<String, Object> generatePrediagnosis(@PathVariable UUID id,
        @Valid @RequestBody PrediagnosisRequest draft, HttpServletRequest request) {
        return prediagnosisService.generate(id, actorId(request), actor(request),
            draft.additionalSymptoms(), draft.observations());
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

    private UUID actorId(HttpServletRequest request) {
        return UUID.fromString((String) actor(request).get("id"));
    }
}
