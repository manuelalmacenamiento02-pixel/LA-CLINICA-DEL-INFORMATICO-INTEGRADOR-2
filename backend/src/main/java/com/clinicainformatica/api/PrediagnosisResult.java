package com.clinicainformatica.api;

import java.util.List;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record PrediagnosisResult(
    @NotBlank @Size(max = 300) String classification,
    @NotBlank @Pattern(regexp = "BAJA|MEDIA|ALTA") String suggestedPriority,
    @NotEmpty @Size(max = 8) List<@NotBlank @Size(max = 500) String> possibleCauses,
    @NotEmpty @Size(max = 8) List<@NotBlank @Size(max = 500) String> recommendedTests,
    @NotEmpty @Size(max = 8) List<@NotBlank @Size(max = 500) String> recommendations,
    @NotEmpty @Size(max = 8) List<@NotBlank @Size(max = 500) String> warnings
) {}
