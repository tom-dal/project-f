package com.debtcollection.util;

import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

/**
 * Utility class to generate password hashes for test data
 */
public class PasswordHashGenerator {

    @Test
    public void generateAdminPasswordHash() {
        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
        String password = "admin";
        String hash = encoder.encode(password);
        
        System.out.println("Password: " + password);
        System.out.println("Hash: " + hash);
        System.out.println("Verification: " + encoder.matches(password, hash));
        
        // Verify against the current hash in the database
        String currentHash = "$2a$10$pb8/onFFXbiPMlRLA9J73.JMjmRyaxgUmobY/tRtE1LiJsDbVLCSy";
        System.out.println("Matches current hash: " + encoder.matches(password, currentHash));
    }
}
