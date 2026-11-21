package com.clinicainformatica.api;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
@Validated
public class SprintSixController {
    private final SprintSixService sprintSixService;
    private final BackupService backupService;
    private final String geminiApiKey;

    public SprintSixController(SprintSixService sprintSixService, BackupService backupService,
        @Value("${spring.ai.google.genai.api-key:}") String geminiApiKey) {
        this.sprintSixService = sprintSixService;
        this.backupService = backupService;
        this.geminiApiKey = geminiApiKey;
    }

    @GetMapping("/indicators/dashboard")
    public Map<String, Object> dashboardIndicators() {
        return sprintSixService.dashboardIndicators();
    }

    @GetMapping("/indicators/services")
    public Map<String, Object> serviceIndicators(
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
        @RequestParam(required = false) String status,
        @RequestParam(required = false) UUID technician) {
        validateDateRange(from, to);
        if (status != null && !List.of("PENDIENTE", "ASIGNADA", "EN_ATENCION", "FINALIZADA",
            "CERRADA", "CANCELADA").contains(status)) {
            throw new IllegalArgumentException("Estado no válido.");
        }
        return sprintSixService.serviceIndicators(from, to, status, technician);
    }

    @GetMapping("/admin/audit")
    public Map<String, Object> audit(
        @RequestParam(defaultValue = "0") @Min(0) @Max(1_000_000) int page,
        @RequestParam(defaultValue = "25") @Min(1) @Max(100) int size,
        @RequestParam(defaultValue = "") String search,
        @RequestParam(required = false) UUID user,
        @RequestParam(defaultValue = "") String module,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
        @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
        @RequestParam(defaultValue = "") String result) {
        validateDateRange(from, to);
        if (result != null && !result.isEmpty() && !List.of("SUCCESS", "FAILED").contains(result)) {
            throw new IllegalArgumentException("Resultado no válido.");
        }
        return sprintSixService.auditEvents(page, size, search, user, module, from, to, result);
    }

    @GetMapping("/admin/backups")
    public List<Map<String, Object>> backups() {
        return backupService.history();
    }

    @PostMapping("/admin/backups")
    public Map<String, Object> createBackup(HttpServletRequest request) {
        return backupService.create(actorId(request));
    }

    @PostMapping("/admin/backups/{id}/restore")
    public Map<String, Object> restoreBackup(@PathVariable UUID id, HttpServletRequest request) {
        Map<String, Object> actor = currentActor(request);
        if (!"ADMINISTRADOR".equals(actor.get("role"))) {
            throw new ApiException(org.springframework.http.HttpStatus.FORBIDDEN, "forbidden",
                "Solo un administrador puede autorizar la restauración de un respaldo.");
        }
        String requesterName = (actor.get("firstName") + " " + actor.get("lastName")).toString();
        return backupService.restore(id, UUID.fromString((String) actor.get("id")), requesterName);
    }

    @GetMapping("/admin/backups/{id}/download")
    public ResponseEntity<FileSystemResource> downloadBackup(@PathVariable UUID id) {
        FileSystemResource resource = backupService.download(id);
        return ResponseEntity.ok()
            .contentType(MediaType.APPLICATION_OCTET_STREAM)
            .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.attachment()
                .filename(resource.getFilename()).build().toString())
            .body(resource);
    }

    @GetMapping("/admin/monitoring")
    public Map<String, Object> monitoring() {
        return sprintSixService.monitor(geminiApiKey);
    }

    private void validateDateRange(LocalDate from, LocalDate to) {
        if (from != null && to != null && from.isAfter(to)) {
            throw new IllegalArgumentException("La fecha inicial no puede ser posterior a la fecha final.");
        }
    }

    private UUID actorId(HttpServletRequest request) {
        return UUID.fromString((String) currentActor(request).get("id"));
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> currentActor(HttpServletRequest request) {
        return (Map<String, Object>) request.getAttribute("currentUser");
    }
}
