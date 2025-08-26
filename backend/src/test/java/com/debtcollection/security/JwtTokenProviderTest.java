package com.debtcollection.security;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class JwtTokenProviderTest {

    private JwtTokenProvider provider;
    private Authentication auth;

    @BeforeEach
    void setUp() {
        provider = new JwtTokenProvider();
        ReflectionTestUtils.setField(provider, "jwtSecret", "dGhpc2lzYXZlcnlsb25nc2VjcmV0a2V5Zm9yand0dG9rZW5nZW5lcmF0aW9u");
        ReflectionTestUtils.setField(provider, "jwtExpirationInMs", 2000L);
        UserDetails principal = new User("alice", "pwd", List.of(new SimpleGrantedAuthority("ROLE_USER"), new SimpleGrantedAuthority("ADMIN")));
        auth = new UsernamePasswordAuthenticationToken(principal, "pwd", principal.getAuthorities());
    }

    @Test
    void generate_and_validate_and_parse() {
        String token = provider.generateToken(auth);
        assertNotNull(token);
        assertTrue(provider.validateToken(token));
        assertEquals("alice", provider.getUsernameFromToken(token));
        var authentication = provider.getAuthentication(token);
        assertEquals("alice", authentication.getName());
        assertEquals(2, authentication.getAuthorities().size());
    }

    @Test
    void passwordChangeToken_flagged() {
        UserDetails principal = (UserDetails) auth.getPrincipal();
        String token = provider.generatePasswordChangeToken(principal);
        assertTrue(provider.isPasswordChangeToken(token));
        String normal = provider.generateToken(auth);
        assertFalse(provider.isPasswordChangeToken(normal));
    }

    @Test
    void expiredToken_notValid() throws InterruptedException {
        ReflectionTestUtils.setField(provider, "jwtExpirationInMs", 1L);
        String token = provider.generateToken(auth);
        Thread.sleep(5);
        assertFalse(provider.validateToken(token));
    }

    @Test
    void tamperedSignature_notValid() {
        String token = provider.generateToken(auth);
        String[] parts = token.split("\\.");
        String sig = parts[2];
        // Change first character of signature segment to ensure signature mismatch
        char first = sig.charAt(0);
        char replacement = first != 'a' ? 'a' : 'b';
        sig = replacement + sig.substring(1);
        String tampered = parts[0] + "." + parts[1] + "." + sig;
        assertFalse(provider.validateToken(tampered));
    }

    @Test
    void malformedToken_notValid() {
        String malformed = "abc.def.ghi";
        assertFalse(provider.validateToken(malformed));
    }
}
