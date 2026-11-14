package com.clinicainformatica.api;

import com.google.genai.Client;
import com.google.genai.types.HttpOptions;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.model.ChatModel;
import org.springframework.ai.google.genai.GoogleGenAiChatModel;
import org.springframework.ai.google.genai.GoogleGenAiChatOptions;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Conditional;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Condition;
import org.springframework.context.annotation.ConditionContext;
import org.springframework.core.type.AnnotatedTypeMetadata;

@Configuration(proxyBeanMethods = false)
@Conditional(GeminiConfiguration.ApiKeyConfigured.class)
public class GeminiConfiguration {
    @Bean
    Client geminiClient(
        @Value("${spring.ai.google.genai.api-key}") String apiKey,
        @Value("${clinica.ai.timeout-ms:45000}") int timeoutMillis) {
        if (timeoutMillis < 1) {
            throw new IllegalArgumentException("GEMINI_TIMEOUT_MS debe ser mayor que cero.");
        }
        return Client.builder()
            .apiKey(apiKey)
            .httpOptions(HttpOptions.builder().timeout(timeoutMillis).build())
            .build();
    }

    @Bean
    ChatModel geminiChatModel(
        Client geminiClient,
        @Value("${spring.ai.google.genai.chat.options.model:gemini-3.8-flash}") String model,
        @Value("${spring.ai.google.genai.chat.options.temperature:0.2}") double temperature) {
        if (model.isBlank()) {
            throw new IllegalArgumentException("GEMINI_MODEL no puede estar vacío.");
        }
        return GoogleGenAiChatModel.builder()
            .genAiClient(geminiClient)
            .options(GoogleGenAiChatOptions.builder()
                .model(model)
                .temperature(temperature)
                .build())
            .build();
    }

    @Bean
    ChatClient.Builder geminiChatClientBuilder(ChatModel geminiChatModel) {
        return ChatClient.builder(geminiChatModel);
    }

    static final class ApiKeyConfigured implements Condition {
        @Override
        public boolean matches(ConditionContext context, AnnotatedTypeMetadata metadata) {
            String apiKey = context.getEnvironment().getProperty("GEMINI_API_KEY");
            if (apiKey == null) {
                apiKey = context.getEnvironment().getProperty("spring.ai.google.genai.api-key");
            }
            return apiKey != null && !apiKey.isBlank();
        }
    }
}
