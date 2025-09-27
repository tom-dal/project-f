package com.debtcollection.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Bean;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.containers.MongoDBContainer;

@Configuration
public class MongoTestContainerConfig {

    @Bean(initMethod = "start", destroyMethod = "stop")
    @ServiceConnection // Spring Boot will wire spring.data.mongodb.uri from this container
    public MongoDBContainer mongoDBContainer() {
        // USER PREFERENCE: explicit Mongo version to ensure deterministic CI builds
        return new MongoDBContainer("mongo:7.0.5");
    }
}

