package com.clinicainformatica.api;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class SprintFiveController {
    private static final Set<String> ORDER_STATUSES = Set.of(
        "PENDIENTE", "ASIGNADA", "EN_ATENCION", "FINALIZADA", "CERRADA", "CANCELADA");
    private final SprintFiveRepository repository;

    public SprintFiveController(SprintFiveRepository repository) {
        this.repository = repository;
    }

    public record PublicTrackingRequest(
        @NotBlank @Pattern(regexp = "(?i)OS-[0-9]{6,}") String code,
        @NotBlank @Pattern(regexp = "[0-9+(). -]{7,30}") String phone
    ) {}

    @GetMapping("/api/equipment/{id}/history")
    public Map<String, Object> equipmentHistory(@PathVariable UUID id,
        @RequestParam(defaultValue = "") String status,
        @RequestParam(required = false) LocalDate from,
        @RequestParam(required = false) LocalDate to) {
        validateStatus(status);
        if (from != null && to != null && from.isAfter(to)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "invalid-date-range",
                "La fecha inicial no puede ser posterior a la fecha final.");
        }
        Map<String, Object> result = repository.equipmentHistory(id, status, from, to);
        if (result == null) {
            throw notFound();
        }
        return result;
    }

    @GetMapping("/api/tracking/orders")
    public List<Map<String, Object>> trackingOrders(@RequestParam(defaultValue = "") String q,
        @RequestParam(defaultValue = "") String status, HttpServletRequest request) {
        validateStatus(status);
        if (q.length() > 100) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "invalid-search",
                "El término de búsqueda supera el largo permitido.");
        }
        Map<String, Object> actor = actor(request);
        UUID technicianId = "TÉCNICO".equals(actor.get("role"))
            ? UUID.fromString((String) actor.get("id")) : null;
        return repository.trackingOrders(q, status, technicianId);
    }

    @GetMapping("/api/tracking/orders/{id}")
    public Map<String, Object> trackingDetail(@PathVariable UUID id, HttpServletRequest request) {
        Map<String, Object> actor = actor(request);
        UUID technicianId = "TÉCNICO".equals(actor.get("role"))
            ? UUID.fromString((String) actor.get("id")) : null;
        Map<String, Object> result = repository.trackingDetail(id, technicianId);
        if (result == null) {
            throw notFound();
        }
        return result;
    }

    @PostMapping("/api/public/tracking")
    public Map<String, Object> publicTracking(@Valid @RequestBody PublicTrackingRequest draft) {
        Map<String, Object> result = repository.publicTracking(draft.code(), draft.phone());
        if (result == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "tracking-not-found",
                "No se encontró un servicio con esos datos. Verifica el código y el teléfono asociado.");
        }
        return result;
    }

    private void validateStatus(String status) {
        if (!status.isBlank() && !ORDER_STATUSES.contains(status)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "invalid-status",
                "El filtro de estado no es válido.");
        }
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

    private ApiException notFound() {
        return new ApiException(HttpStatus.NOT_FOUND, "not-found", "No se encontró el registro solicitado.");
    }
}
