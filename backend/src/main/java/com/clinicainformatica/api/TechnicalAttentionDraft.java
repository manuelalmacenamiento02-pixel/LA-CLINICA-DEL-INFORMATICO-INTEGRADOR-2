package com.clinicainformatica.api;

import java.time.LocalDate;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record TechnicalAttentionDraft(
    @NotNull LocalDate attendedAt,
    @NotBlank @Size(max = 10000) String diagnosis,
    @NotBlank @Size(max = 10000) String actionsPerformed,
    @NotNull @Size(max = 10000) String performedTests,
    @NotNull @Size(max = 10000) String partsUsed,
    @NotNull @Size(max = 10000) String observations,
    @NotNull @Size(max = 10000) String resultSummary
) {}
