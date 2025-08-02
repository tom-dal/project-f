package com.debtcollection.service;

import com.debtcollection.repository.UserRepository;
import com.debtcollection.security.JwtService;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import lombok.Builder;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.CredentialsExpiredException;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthenticationService {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;

    public AuthenticationResponse authenticate(AuthenticationRequest request) {
        log.info("🔐 AUTHENTICATE START - Username: {}", request.username());
        
        var user = userRepository.findByUsername(request.username())
            .orElseThrow(() -> {
                log.error("❌ USER NOT FOUND - Username: {}", request.username());
                return new UsernameNotFoundException("User not found");
            });

        log.info("👤 USER FOUND - Username: {}, PasswordExpired: {}", user.getUsername(), user.isPasswordExpired());

        try {
            log.info("🔍 AUTHENTICATION START - Username: {}", request.username());

            // Attempt to authenticate the user
            authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.username(), request.password())
            );
            
            log.info("✅ AUTHENTICATION SUCCESS - Username: {}", request.username());
            // If we get here, authentication was successful
            String token = jwtService.generateToken(user);
            log.info("🔑 REGULAR TOKEN GENERATED - Username: {}", request.username());

            return AuthenticationResponse.builder()
                .token(token)
                .passwordExpired(false)
                .build();

        } catch (CredentialsExpiredException e) {
            log.warn("⏰ CREDENTIALS EXPIRED - Username: {}", request.username());
            // Password is correct but expired
            if (passwordEncoder.matches(request.password(), user.getPassword())) {
                log.info("✅ PASSWORD MATCH (BUT EXPIRED) - Username: {}", request.username());
                String passwordChangeToken = jwtService.generatePasswordChangeToken(user);
                log.info("🔑 PASSWORD CHANGE TOKEN GENERATED - Username: {}", request.username());

                return AuthenticationResponse.builder()
                    .token(passwordChangeToken)
                    .passwordExpired(true)
                    .build();
            }
            log.error("❌ PASSWORD MISMATCH (EXPIRED CREDENTIALS) - Username: {}", request.username());
            throw new BadCredentialsException("Invalid credentials");
        } catch (BadCredentialsException e) {
            log.error("❌ BAD CREDENTIALS - Username: {}, Error: {}", request.username(), e.getMessage());
            throw new BadCredentialsException("Invalid credentials");
        } catch (Exception e) {
            log.error("💥 UNEXPECTED AUTH ERROR - Username: {}, Error: {}", request.username(), e.getMessage());
            log.error("🔍 UNEXPECTED AUTH ERROR - Exception: ", e);
            throw e;
        }
    }

    public AuthenticationResponse changePassword(ChangePasswordRequest request, String username) {
        log.info("🔄 CHANGE PASSWORD START - Username: {}", username);
        
        var user = userRepository.findByUsername(username)
            .orElseThrow(() -> {
                log.error("❌ USER NOT FOUND FOR PASSWORD CHANGE - Username: {}", username);
                return new UsernameNotFoundException("User not found");
            });

        log.info("👤 USER FOUND FOR PASSWORD CHANGE - Username: {}, PasswordExpired: {}", 
                user.getUsername(), user.isPasswordExpired());

        // Verify old password
        log.info("🔍 VERIFYING OLD PASSWORD - Username: {}", username);
        boolean oldPasswordMatches = passwordEncoder.matches(request.oldPassword(), user.getPassword());
        log.info("🔐 OLD PASSWORD CHECK - Username: {}, Matches: {}", username, oldPasswordMatches);
        
        if (!oldPasswordMatches) {
            log.error("❌ OLD PASSWORD INCORRECT - Username: {}", username);
            throw new IllegalArgumentException("Current password is incorrect");
        }

        // Validate new password
        String newPassword = request.newPassword();
        log.info("🔍 VALIDATING NEW PASSWORD - Username: {}, Length: {}", username, newPassword.length());
        
        boolean isValid = isPasswordValid(newPassword);
        log.info("✅ NEW PASSWORD VALIDATION - Username: {}, Valid: {}", username, isValid);
        
        if (!isValid) {
            log.error("❌ NEW PASSWORD INVALID - Username: {}", username);
            throw new IllegalArgumentException("Password must be at least 8 characters long and contain at least one uppercase letter, one number, and one special character");
        }

        // Update password and reset expired flag
        log.info("💾 UPDATING PASSWORD IN DATABASE - Username: {}", username);
        user.setPassword(passwordEncoder.encode(newPassword));
        user.setPasswordExpired(false);
        userRepository.save(user);
        log.info("✅ PASSWORD UPDATED IN DATABASE - Username: {}", username);

        // Generate and return new JWT
        log.info("🔑 GENERATING NEW TOKEN - Username: {}", username);
        String newToken = jwtService.generateToken(user);
        log.info("✅ NEW TOKEN GENERATED - Username: {}, TokenLength: {}", username, newToken.length());

        return AuthenticationResponse.builder()
            .token(newToken)
            .passwordExpired(false)
            .build();
    }

    private boolean isPasswordValid(String password) {
        // Minimum 8 characters
        if (password.length() < 8) {
            return false;
        }

        // At least one uppercase letter
        if (!password.matches(".*[A-Z].*")) {
            return false;
        }

        // At least one number
        if (!password.matches(".*\\d.*")) {
            return false;
        }

        // At least one special character
        if (!password.matches(".*[!@#$%^&*()\\-_=+\\[\\]{};:'\",.<>/?].*")) {
            return false;
        }

        return true;
    }

    public boolean validateToken(String token) {
        log.info("🔍 VALIDATE TOKEN START");

        try {
            String username = jwtService.extractUsername(token);
            log.info("👤 EXTRACTED USERNAME FROM TOKEN - Username: {}", username);
            
            var userDetails = userRepository.findByUsername(username)
                .orElseThrow(() -> {
                    log.error("❌ USER NOT FOUND FOR TOKEN VALIDATION - Username: {}", username);
                    return new UsernameNotFoundException("User not found");
                });
            
            log.info("👤 USER FOUND FOR TOKEN VALIDATION - Username: {}", userDetails.getUsername());
            
            boolean isValid = jwtService.isTokenValid(token, userDetails);
            log.info("✅ TOKEN VALIDATION RESULT - Username: {}, Valid: {}", username, isValid);
            
            return isValid;
        } catch (Exception e) {
            log.error("💥 TOKEN VALIDATION ERROR - Error: {}", e.getMessage());
            log.error("🔍 TOKEN VALIDATION ERROR - Exception: ", e);
            return false;
        }
    }

    public record AuthenticationRequest(String username, String password) {}

    public record ChangePasswordRequest(String oldPassword, String newPassword) {}

    @Builder
    public static class AuthenticationResponse {
        @JsonProperty("token")
        private final String token;
        
        @JsonProperty("passwordExpired")
        private final boolean passwordExpired;
        
        public AuthenticationResponse(String token, boolean passwordExpired) {
            this.token = token;
            this.passwordExpired = passwordExpired;
        }
        
        public String getToken() {
            return token;
        }
        
        public boolean isPasswordExpired() {
            return passwordExpired;
        }
        
        // Keep the record-style methods for backwards compatibility
        public String token() {
            return token;
        }
        
        public boolean passwordExpired() {
            return passwordExpired;
        }
    }
}
