package com.clinicainformatica.api;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import jakarta.validation.Validator;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.google.genai.GoogleGenAiChatOptions;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class PrediagnosisService {
    private static final Logger logger = LoggerFactory.getLogger(PrediagnosisService.class);
    private final JdbcTemplate jdbc;
    private final ClinicRepository clinicRepository;
    private final TechnicalAttentionRepository repository;
    private final TechnicalAttentionService attentionService;
    private final ObjectProvider<ChatClient.Builder> chatClientBuilders;
    private final ObjectMapper objectMapper;
    private final Validator validator;
    private final String apiKey;
    private final String model;

    public PrediagnosisService(JdbcTemplate jdbc, ClinicRepository clinicRepository,
        TechnicalAttentionRepository repository,
        TechnicalAttentionService attentionService, ObjectProvider<ChatClient.Builder> chatClientBuilders,
        ObjectMapper objectMapper, Validator validator,
        @Value("${spring.ai.google.genai.api-key:}") String apiKey,
        @Value("${spring.ai.google.genai.chat.options.model:gemini-3.8-flash}") String model) {
        this.jdbc = jdbc;
        this.clinicRepository = clinicRepository;
        this.repository = repository;
        this.attentionService = attentionService;
        this.chatClientBuilders = chatClientBuilders;
        this.objectMapper = objectMapper;
        this.validator = validator;
        this.apiKey = apiKey;
        this.model = model;
    }

    public List<Map<String, Object>> list(UUID orderId, Map<String, Object> actor) {
        attentionService.requireCanAttend(orderId, actor);
        List<Map<String, Object>> items = repository.prediagnoses(orderId);
        for (Map<String, Object> item : items) {
            item.put("result", parseJson(item.remove("resultJson")));
            item.put("modifiedResult", parseJson(item.remove("modifiedJson")));
        }
        return items;
    }

    public Map<String, Object> generate(UUID orderId, UUID actorId, Map<String, Object> actor,
        String additionalSymptoms, String observations) {
        attentionService.requireCanAttend(orderId, actor);
        Map<String, Object> context = orderContext(orderId);
        if ("FINALIZADA".equals(context.get("status"))) {
            throw new ApiException(HttpStatus.CONFLICT, "order-finalized",
                "No se puede generar un prediagnóstico para una orden finalizada.");
        }
        Map<String, Object> input = new LinkedHashMap<>();
        input.put("equipmentType", context.get("equipmentType"));
        input.put("brand", context.get("brand"));
        input.put("model", context.get("model"));
        input.put("technicalCharacteristics", context.get("characteristics"));
        input.put("reportedProblem", context.get("reportedProblem"));
        input.put("initialObservations", context.get("initialObservations"));
        input.put("additionalSymptoms", additionalSymptoms.trim());
        input.put("observations", observations.trim());
        String inputJson = writeJson(input);

        if (apiKey.isBlank()) {
            UUID failedId = saveFailure(orderId, actorId, inputJson, "Gemini no está configurado en el servidor.");
            clinicRepository.audit(actorId,"GENERATE_PREDIAGNOSIS","ai_prediagnoses",
                failedId,"FAILED","Gemini no está configurado");
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "ai-not-configured",
                "El prediagnóstico no está disponible: falta configurar GEMINI_API_KEY en el backend.");
        }
        ChatClient.Builder builder = chatClientBuilders.getIfAvailable();
        if (builder == null) {
            UUID failedId = saveFailure(orderId, actorId, inputJson, "El proveedor Gemini no está disponible.");
            clinicRepository.audit(actorId,"GENERATE_PREDIAGNOSIS","ai_prediagnoses",
                failedId,"FAILED","El proveedor Gemini no está disponible");
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "ai-not-configured",
                "El servicio Gemini no está disponible en este servidor.");
        }

        String response;
        PrediagnosisResult result;
        try {
            response = builder.build().prompt()
                .system("""
                    Eres un asistente de prediagnóstico para técnicos de reparación informática.
                    Analiza solo los datos técnicos recibidos; no inventes mediciones ni afirmes
                    que una prueba ya fue ejecutada. No emitas un diagnóstico definitivo.
                    Responde únicamente con un objeto JSON válido que tenga exactamente estas
                    claves: classification (string breve), suggestedPriority (BAJA, MEDIA o ALTA),
                    possibleCauses (lista de causas posibles), recommendedTests (lista de pruebas
                    seguras y concretas), recommendations (lista de recomendaciones iniciales) y
                    warnings (lista de limitaciones o advertencias). Usa listas no vacías y máximo
                    8 elementos por lista. Advierte cuando se requieran mediciones profesionales
                    o precauciones de seguridad.
                    """)
                .options(GoogleGenAiChatOptions.builder()
                    .responseMimeType("application/json"))
                .user(user -> user.text("Datos técnicos JSON:\n{technicalData}")
                    .param("technicalData", inputJson))
                .call().content();
            if (response == null || response.isBlank()) {
                throw new IllegalStateException("El modelo devolvió una respuesta vacía.");
            }
            result = parseResponse(response);
        } catch (RuntimeException | JsonProcessingException e) {
            Throwable cause = e.getCause() == null ? e : e.getCause();
            logger.warn("Gemini prediagnosis request failed ({})", cause.getClass().getSimpleName());
            clinicRepository.jdbc().update("""
                INSERT INTO monitoring_checks(component,status,message)
                VALUES ('gemini','ERROR','Solicitud Gemini fallida')
                """);
            UUID failedId = saveFailure(orderId, actorId, inputJson,
                "Gemini no respondió con un prediagnóstico válido.");
            clinicRepository.audit(actorId,"GENERATE_PREDIAGNOSIS","ai_prediagnoses",
                failedId,"FAILED","Falló la generación del prediagnóstico");
            throw new ApiException(HttpStatus.BAD_GATEWAY, "ai-generation-failed",
                "No se pudo generar un prediagnóstico válido con Gemini. Puedes volver a intentarlo.");
        }
        String id = saveSuccess(orderId, actorId, inputJson, response, result);
        clinicRepository.jdbc().update("""
            INSERT INTO monitoring_checks(component,status,message)
            VALUES ('gemini','OK','Solicitud Gemini completada')
            """);
        clinicRepository.audit(actorId,"GENERATE_PREDIAGNOSIS","ai_prediagnoses",
            UUID.fromString(id),"SUCCESS","Prediagnóstico generado");
        Map<String, Object> generated = new LinkedHashMap<>();
        generated.put("id", id);
        generated.put("status", "GENERADO");
        generated.put("model", model);
        generated.put("result", result);
        generated.put("originalResponse", response);
        generated.put("requestedAt", jdbc.queryForObject(
            "SELECT requested_at::text FROM ai_prediagnoses WHERE id=?",
            String.class, UUID.fromString(id)));
        generated.put("completedAt", jdbc.queryForObject(
            "SELECT completed_at::text FROM ai_prediagnoses WHERE id=?",
            String.class, UUID.fromString(id)));
        generated.put("validationStatus", null);
        generated.put("modifiedResult", null);
        generated.put("validationObservations", null);
        generated.put("validatedAt", null);
        generated.put("validatedBy", null);
        return generated;
    }

    public Map<String, Object> validate(UUID prediagnosisId, UUID actorId,
        Map<String, Object> actor, PrediagnosisValidationDraft draft) {
        Map<String, Object> prediagnosis = repository.prediagnosis(prediagnosisId);
        if (prediagnosis == null) {
            throw new ApiException(HttpStatus.NOT_FOUND, "not-found", "No se encontró el prediagnóstico.");
        }
        UUID orderId = UUID.fromString((String) prediagnosis.get("orderId"));
        if (!clinicRepository.can((String) actor.get("role"), "ai-prediagnosis")) {
            throw new ApiException(HttpStatus.FORBIDDEN, "forbidden",
                "No tienes permiso para validar recomendaciones de IA.");
        }
        attentionService.requireCanAttend(orderId, actor);
        if ("FINALIZADA".equals(repository.orderStatus(orderId))) {
            throw new ApiException(HttpStatus.CONFLICT, "order-finalized",
                "No se puede validar un prediagnóstico de una orden finalizada.");
        }
        String decision = draft.decision();
        if ("ERROR".equals(prediagnosis.get("status"))) {
            throw new ApiException(HttpStatus.CONFLICT, "ai-result-unavailable",
                "No se puede validar un prediagnóstico que no se generó correctamente.");
        }
        if (jdbc.queryForObject(
            "SELECT EXISTS(SELECT 1 FROM ai_validations WHERE prediagnosis_id=?)",
            Boolean.class, prediagnosisId)) {
            throw new ApiException(HttpStatus.CONFLICT, "ai-already-validated",
                "Este prediagnóstico ya fue revisado.");
        }
        if ("DESCARTADO".equals(decision) && draft.observations().isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "discard-reason-required",
                "Indica brevemente por qué descartas el prediagnóstico.");
        }
        String modifiedJson = null;
        if ("MODIFICADO".equals(decision)) {
            if (draft.modifiedResult() == null) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "modified-result-required",
                    "Completa la versión modificada del prediagnóstico.");
            }
            validate(draft.modifiedResult());
            modifiedJson = writeJson(draft.modifiedResult());
        } else if (draft.modifiedResult() != null) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "invalid-data",
                "Solo una decisión MODIFICADO debe incluir conclusiones editadas.");
        }
        UUID validationId = UUID.randomUUID();
        jdbc.update("""
            INSERT INTO ai_validations(id,prediagnosis_id,technician_id,decision,final_diagnosis,
              modified_data,observations)
            VALUES (?,?,?,?,NULL,?::jsonb,?)
            """, validationId, prediagnosisId, actorId, decision, modifiedJson,
            draft.observations().trim());
        clinicRepository.audit(actorId,"VALIDATE_PREDIAGNOSIS","ai_validations",
            validationId,"SUCCESS","Prediagnóstico validado");
        return Map.of("id", prediagnosisId.toString(), "decision", decision,
            "validatedAt", jdbc.queryForObject(
                "SELECT validated_at::text FROM ai_validations WHERE prediagnosis_id=?",
                String.class, prediagnosisId));
    }

    public Map<String, Object> validateRequest(UUID id, UUID actorId,
        Map<String, Object> actor, PrediagnosisValidationDraft draft) {
        validate(id, actorId, actor, draft);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("id", id.toString());
        result.put("decision", draft.decision());
        result.put("modifiedResult", draft.modifiedResult());
        result.put("observations", draft.observations());
        result.put("validatedAt", jdbc.queryForObject(
            "SELECT validated_at::text FROM ai_validations WHERE prediagnosis_id=?",
            String.class, id));
        return result;
    }

    private Map<String, Object> orderContext(UUID orderId) {
        var rows = jdbc.queryForList("""
            SELECT so.status_code AS status,so.reported_problem AS "reportedProblem",
              so.intake_condition AS "initialObservations",equipment.type AS "equipmentType",
              equipment.brand,equipment.model,equipment.characteristics
            FROM service_orders so JOIN equipment ON equipment.id=so.equipment_id
            WHERE so.id=?
            """, orderId);
        if (rows.isEmpty()) {
            throw new ApiException(HttpStatus.NOT_FOUND, "not-found", "No se encontró la orden.");
        }
        return rows.getFirst();
    }

    private void validate(PrediagnosisResult result) {
        var violations = validator.validate(result);
        if (!violations.isEmpty()) {
            throw new IllegalArgumentException("La respuesta de Gemini no cumple el formato requerido.");
        }
    }

    PrediagnosisResult parseResponse(String response) throws JsonProcessingException {
        String json = response.trim();
        if (json.startsWith("```")) {
            int contentStart = json.indexOf('\n');
            int closingFence = json.lastIndexOf("```");
            if (contentStart < 0 || closingFence <= contentStart) {
                throw new IllegalArgumentException("La respuesta de Gemini no contiene JSON válido.");
            }
            json = json.substring(contentStart + 1, closingFence).trim();
        }
        PrediagnosisResult result = objectMapper.readValue(json, PrediagnosisResult.class);
        if (result == null) {
            throw new IllegalArgumentException("La respuesta de Gemini no contiene un objeto JSON.");
        }
        validate(result);
        return result;
    }

    private String saveSuccess(UUID orderId, UUID actorId, String inputJson,
        String originalResponse, PrediagnosisResult result) {
        String resultJson = writeJson(result);
        UUID id = UUID.randomUUID();
        jdbc.update("""
            INSERT INTO ai_prediagnoses(id,order_id,requested_by,model,input_data,
              generated_diagnosis,result_data,status,completed_at)
            VALUES (?,?,?,?,?::jsonb,?,?::jsonb,'GENERADO',now())
            """, id, orderId, actorId, model, inputJson, originalResponse, resultJson);
        return id.toString();
    }

    private UUID saveFailure(UUID orderId, UUID actorId, String inputJson, String message) {
        UUID id = UUID.randomUUID();
        jdbc.update("""
            INSERT INTO ai_prediagnoses(id,order_id,requested_by,model,input_data,status,
              error_message,completed_at)
            VALUES (?,?,?,?,?::jsonb,'ERROR',?,now())
            """, id, orderId, actorId, model, inputJson, message);
        return id;
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "serialization-error",
                "No se pudo procesar la información del prediagnóstico.");
        }
    }

    private JsonNode parseJson(Object value) {
        if (value == null) return null;
        try {
            return objectMapper.readTree(value.toString());
        } catch (JsonProcessingException e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "stored-ai-data-invalid",
                "No se pudo leer la información guardada del prediagnóstico.");
        }
    }

}
