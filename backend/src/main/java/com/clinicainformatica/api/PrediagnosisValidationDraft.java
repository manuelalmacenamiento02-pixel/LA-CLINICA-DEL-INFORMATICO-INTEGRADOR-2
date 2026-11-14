package com.clinicainformatica.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record PrediagnosisValidationDraft(
    @NotBlank @Pattern(regexp = "ACEPTADO|MODIFICADO|DESCARTADO") String decision,
    @Valid PrediagnosisResult modifiedResult,
    @NotNull @Size(max = 2000) String observations
) {}
