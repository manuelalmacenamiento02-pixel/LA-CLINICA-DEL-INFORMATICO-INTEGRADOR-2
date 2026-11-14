package com.clinicainformatica.api;

import com.google.genai.Client;
import org.junit.jupiter.api.Test;
import org.springframework.ai.google.genai.GoogleGenAiChatModel;
import static org.junit.jupiter.api.Assertions.assertEquals;

class GeminiConfigurationTests {
    @Test
    void acceptsGeminiModelsNotListedInSpringAiEnum() {
        try (Client client = Client.builder().apiKey("test-api-key").build()) {
            var chatModel = (GoogleGenAiChatModel) new GeminiConfiguration()
                .geminiChatModel(client, "gemini-3.8-flash", 0.2);

            assertEquals("gemini-3.8-flash", chatModel.getOptions().getModel());
        }
    }
}
