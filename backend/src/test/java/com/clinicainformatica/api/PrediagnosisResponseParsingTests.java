package com.clinicainformatica.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.Validation;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.jdbc.core.JdbcTemplate;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.mock;

class PrediagnosisResponseParsingTests {
    private static final String VALID_RESULT = """
        {"classification":"Falla de encendido","suggestedPriority":"MEDIA",
         "possibleCauses":["Batería descargada"],
         "recommendedTests":["Verificar el adaptador de corriente"],
         "recommendations":["Inspeccionar el cable de alimentación"],
         "warnings":["No abrir el equipo conectado a la corriente"]}
        """;

    @Test
    void parsesJsonWrappedInMarkdownFence() {
        try (var validatorFactory = Validation.buildDefaultValidatorFactory()) {
            PrediagnosisService service = service(validatorFactory.getValidator());

            PrediagnosisResult result = assertDoesNotThrow(
                () -> service.parseResponse("```json\n" + VALID_RESULT + "\n```"));

            assertEquals("Falla de encendido", result.classification());
            assertEquals("MEDIA", result.suggestedPriority());
            assertEquals(List.of("Batería descargada"), result.possibleCauses());
        }
    }

    @Test
    void stillRejectsResponsesThatDoNotMeetThePrediagnosisContract() {
        try (var validatorFactory = Validation.buildDefaultValidatorFactory()) {
            PrediagnosisService service = service(validatorFactory.getValidator());

            assertThrows(IllegalArgumentException.class,
                () -> service.parseResponse("""
                    {"classification":"","suggestedPriority":"URGENTE",
                     "possibleCauses":[],"recommendedTests":[],
                     "recommendations":[],"warnings":[]}
                    """));
        }
    }

    @SuppressWarnings("unchecked")
    private PrediagnosisService service(jakarta.validation.Validator validator) {
        return new PrediagnosisService(
            mock(JdbcTemplate.class),
            mock(ClinicRepository.class),
            mock(TechnicalAttentionRepository.class),
            mock(TechnicalAttentionService.class),
            mock(ObjectProvider.class),
            new ObjectMapper(),
            validator,
            "",
            "gemini-3.8-flash");
    }
}
