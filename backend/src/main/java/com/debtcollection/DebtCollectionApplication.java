package com.debtcollection;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.mongodb.config.EnableMongoAuditing;
import org.springframework.data.mongodb.repository.config.EnableMongoRepositories;

// USER PREFERENCE: Migrated from JPA to MongoDB configuration
@SpringBootApplication(scanBasePackages = "com.debtcollection")
@EnableMongoRepositories(basePackages = "com.debtcollection.repository")
@EnableMongoAuditing // USER PREFERENCE: MongoDB auditing instead of JPA auditing
public class DebtCollectionApplication {
    public static void main(String[] args) {
        SpringApplication.run(DebtCollectionApplication.class, args);
    }
}
