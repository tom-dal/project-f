package com.debtcollection.config;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

/**
 * Configuration for Embedded MongoDB in development environment.
 * This configuration is activated only when the 'dev' profile is active.
 *
 * Spring Boot 3.x automatically configures Embedded MongoDB when the dependency
 * is present and no external MongoDB connection is configured.
 */
@Configuration
@Profile("dev")
@ConditionalOnProperty(value = "spring.mongodb.embedded.enabled", havingValue = "true", matchIfMissing = true)
@Slf4j
public class EmbeddedMongoConfig {

    public EmbeddedMongoConfig() {
        log.info("🚀 Embedded MongoDB configuration activated for development");
        log.info("📦 MongoDB will start automatically on a random available port");
        log.info("💡 Use 'mvn spring-boot:run -Dspring-boot.run.profiles=dev' to activate this profile");
        log.info("🔧 Spring Boot will auto-configure the embedded instance");
    }
}
