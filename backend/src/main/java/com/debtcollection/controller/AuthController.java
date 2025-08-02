package com.debtcollection.controller;

import com.debtcollection.service.AuthenticationService;
import com.debtcollection.service.AuthenticationService.AuthenticationRequest;
import com.debtcollection.service.AuthenticationService.AuthenticationResponse;
import com.debtcollection.service.AuthenticationService.ChangePasswordRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
@Slf4j
public class AuthController {
    private final AuthenticationService authenticationService;
    private final PasswordEncoder passwordEncoder;

    @PostMapping(value = "/login", produces = "application/json")
    public ResponseEntity<?> authenticate(@RequestBody AuthenticationRequest request) {
        log.info("📝 LOGIN REQUEST - Username: {}", request.username());
        log.info("📝 LOGIN REQUEST - Headers: {}", request);
        try {
            AuthenticationResponse response = authenticationService.authenticate(request);
            log.info("✅ LOGIN SUCCESS - Username: {}, PasswordExpired: {}", request.username(), response.passwordExpired());
            log.info("🔑 LOGIN SUCCESS - Token generated: {}", response.token() != null ? "YES" : "NO");
            return ResponseEntity.ok().header("Content-Type", "application/json").body(response);
        } catch (Exception e) {
            log.error("❌ LOGIN FAILED - Username: {}, Error: {}", request.username(), e.getMessage());
            log.error("💥 LOGIN FAILED - Exception type: {}", e.getClass().getSimpleName());
            // Always return a JSON error response
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .header("Content-Type", "application/json")
                    .body(java.util.Map.of(
                        "error", e.getClass().getSimpleName(),
                        "message", e.getMessage() != null ? e.getMessage() : "Authentication failed"
                    ));
        }
    }

    @PostMapping("/change-password")
    public ResponseEntity<AuthenticationResponse> changePassword(
            @RequestBody ChangePasswordRequest request,
            Authentication authentication
    ) {
        String username = authentication.getName();
        log.info("🔄 CHANGE PASSWORD REQUEST - Username: {}", username);
        log.info("📋 CHANGE PASSWORD REQUEST - Authentication type: {}", authentication.getClass().getSimpleName());
        log.info("🔐 CHANGE PASSWORD REQUEST - Is authenticated: {}", authentication.isAuthenticated());
        log.info("👤 CHANGE PASSWORD REQUEST - Principal: {}", authentication.getPrincipal());
        log.info("🎫 CHANGE PASSWORD REQUEST - Authorities: {}", authentication.getAuthorities());
        
        try {
            AuthenticationResponse response = authenticationService.changePassword(request, username);
            log.info("✅ CHANGE PASSWORD SUCCESS - Username: {}", username);
            log.info("🔑 CHANGE PASSWORD SUCCESS - New token generated: {}", 
                    response.token() != null ? "YES" : "NO");
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("❌ CHANGE PASSWORD FAILED - Username: {}, Error: {}", username, e.getMessage());
            log.error("💥 CHANGE PASSWORD FAILED - Exception type: {}", e.getClass().getSimpleName());
            log.error("🔍 CHANGE PASSWORD FAILED - Stack trace: ", e);
            throw e;
        }
    }

    @GetMapping("/validate")
    public ResponseEntity<Void> validateToken(@RequestHeader("Authorization") String authHeader) {
        log.info("🔍 TOKEN VALIDATION REQUEST");

        try {
            String token = authHeader.substring(7); // Remove "Bearer " prefix
            log.info("🎫 TOKEN VALIDATION - Processing token");

            if (authenticationService.validateToken(token)) {
                log.info("✅ TOKEN VALIDATION SUCCESS");
                return ResponseEntity.ok().build();
            } else {
                log.warn("❌ TOKEN VALIDATION FAILED - Invalid token");
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
            }
        } catch (Exception e) {
            log.error("💥 TOKEN VALIDATION ERROR - Error: {}", e.getMessage());
            log.error("🔍 TOKEN VALIDATION ERROR - Exception: ", e);
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
    }

    @GetMapping("/test-password/{password}")
    public ResponseEntity<String> testPasswordHash(@PathVariable String password) {
        String hashedPassword = passwordEncoder.encode(password);
        boolean matches = passwordEncoder.matches(password, hashedPassword);
        return ResponseEntity.ok("Hash: " + hashedPassword + "\nMatches: " + matches);
    }
}
