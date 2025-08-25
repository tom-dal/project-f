package com.debtcollection.security;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class JwtServiceTest {

    private JwtService jwtService;
    private UserDetails user;

    @BeforeEach
    void setUp() {
        jwtService = new JwtService();
        // Secret base64 (>=256 bit) preso da application-test.properties
        ReflectionTestUtils.setField(jwtService, "secretKey", "dGhpc2lzYXZlcnlsb25nc2VjcmV0a2V5Zm9yand0dG9rZW5nZW5lcmF0aW9u");
        ReflectionTestUtils.setField(jwtService, "jwtExpiration", 2000L); // 2 secondi per test standard
        user = new User("alice", "pwd", Collections.emptyList());
    }

    @Test
    void generateToken_and_validate_success() {
        String token = jwtService.generateToken(user);
        assertNotNull(token);
        assertTrue(jwtService.isTokenValid(token, user));
        assertEquals("alice", jwtService.extractUsername(token));
    }

    @Test
    void isTokenValid_false_when_username_differs() {
        String token = jwtService.generateToken(user);
        UserDetails other = new User("bob", "pwd", Collections.emptyList());
        assertFalse(jwtService.isTokenValid(token, other));
    }

    @Test
    void tokenExpired_returnsFalse() throws InterruptedException {
        ReflectionTestUtils.setField(jwtService, "jwtExpiration", 1L); // 1 ms
        String token = jwtService.generateToken(user);
        Thread.sleep(5); // lascia scadere
        assertFalse(jwtService.isTokenValid(token, user));
    }

    @Test
    void passwordChangeToken_detected() {
        String token = jwtService.generatePasswordChangeToken(user);
        assertTrue(jwtService.isPasswordChangeToken(token));
        // Normal token non marcato
        String normal = jwtService.generateToken(user);
        assertFalse(jwtService.isPasswordChangeToken(normal));
    }

    @Test
    void generateToken_withExtraClaims() {
        Map<String,Object> extra = new HashMap<>();
        extra.put("any", "value");
        String token = jwtService.generateToken(extra, user);
        assertNotNull(token);
        assertEquals("alice", jwtService.extractUsername(token));
    }
}

