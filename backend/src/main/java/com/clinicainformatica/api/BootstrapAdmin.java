package com.clinicainformatica.api;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class BootstrapAdmin implements ApplicationRunner {
    private final ClinicRepository repository;
    private final String username,password;
    public BootstrapAdmin(ClinicRepository repository,@Value("${clinica.bootstrap.username}") String username,
        @Value("${clinica.bootstrap.password}") String password) {this.repository=repository;this.username=username;this.password=password;}
    @Override @Transactional public void run(ApplicationArguments args) {
        repository.jdbc().execute("LOCK TABLE users IN EXCLUSIVE MODE");
        if(repository.jdbc().queryForObject("SELECT count(*) FROM users",Long.class) != 0) return;
        if(password.length() < 10 || password.getBytes(java.nio.charset.StandardCharsets.UTF_8).length > 72)
            throw new IllegalStateException("Configura ADMIN_PASSWORD (10 caracteres como mínimo y 72 bytes como máximo) para crear el primer administrador.");
        if(username.isBlank() || username.trim().length() > 80) throw new IllegalStateException("ADMIN_USERNAME no válido.");
        repository.jdbc().update("INSERT INTO users(first_name,last_name,username,password_hash,role_code) VALUES ('Administrador','Sistema',?,?,'ADMINISTRADOR')",
            username.trim(),new BCryptPasswordEncoder(12).encode(password));
    }
}
