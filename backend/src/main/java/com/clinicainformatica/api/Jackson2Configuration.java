package com.clinicainformatica.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration(proxyBeanMethods = false)
public class Jackson2Configuration {
    @Bean
    ObjectMapper objectMapper() {
        return new ObjectMapper();
    }
}
