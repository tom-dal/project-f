package com.debtcollection.service;

import com.debtcollection.model.User;
import com.debtcollection.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserService implements UserDetailsService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        log.info("Attempting to load user: {}", username);
        try {
            UserDetails user = userRepository.findByUsername(username)
                    .orElseThrow(() -> new UsernameNotFoundException("User not found: " + username));
            log.info("Successfully loaded user: {}", username);
            return user;
        } catch (UsernameNotFoundException e) {
            log.error("Failed to load user: {}", username, e);
            throw e;
        }
    }

    public User getUserFromUserDetails(UserDetails userDetails) {
        return userRepository.findByUsername(userDetails.getUsername())
                .orElseThrow(() -> new UsernameNotFoundException("User not found: " + userDetails.getUsername()));
    }

    // CRUD METHODS
    public List<User> findAll() {
        return userRepository.findAll();
    }

    public User create(String username, String plainPassword, Collection<String> roles, boolean passwordExpired) {
        log.info("Creating user: {}", username);
        if (userRepository.findByUsername(username).isPresent()) {
            throw new IllegalArgumentException("Username already exists");
        }
        if (!isPasswordValid(plainPassword)) {
            throw new IllegalArgumentException("Password must be at least 8 characters long and contain at least one uppercase letter, one number, and one special character");
        }
        User user = new User();
        user.setUsername(username);
        user.setPassword(passwordEncoder.encode(plainPassword));
        user.setPasswordExpired(passwordExpired);
        Set<String> roleSet = (roles == null || roles.isEmpty()) ? Set.of("ROLE_USER") : normalizeRoles(roles);
        user.setRoles(new HashSet<>(roleSet));
        User saved = userRepository.save(user);
        log.info("User created: {} id={}", username, saved.getId());
        return saved;
    }

    public User update(String id, String newPlainPassword, Collection<String> roles, Boolean passwordExpired) {
        log.info("Updating user id={} password?={} roles?={} passwordExpired?={}", id, newPlainPassword != null, roles != null, passwordExpired != null);
        User user = userRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("User not found"));
        if (newPlainPassword != null) {
            if (!isPasswordValid(newPlainPassword)) {
                throw new IllegalArgumentException("Password must be at least 8 characters long and contain at least one uppercase letter, one number, and one special character");
            }
            user.setPassword(passwordEncoder.encode(newPlainPassword));
        }
        if (roles != null) {
            if (roles.isEmpty()) {
                user.setRoles(new HashSet<>(Set.of("ROLE_USER")));
            } else {
                user.setRoles(new HashSet<>(normalizeRoles(roles)));
            }
        }
        if (passwordExpired != null) {
            user.setPasswordExpired(passwordExpired);
        }
        return userRepository.save(user);
    }

    public void delete(String id) {
        if (!userRepository.existsById(id)) {
            throw new IllegalArgumentException("User not found");
        }
        userRepository.deleteById(id);
    }

    private boolean isPasswordValid(String password) {
        if (password == null) return false;
        if (password.length() < 8) return false;
        if (!password.matches(".*[A-Z].*")) return false;
        if (!password.matches(".*\\d.*")) return false;
        if (!password.matches(".*[!@#$%^&*()\\-_=+\\[\\]{};:'\",.<>/?].*")) return false;
        return true;
    }

    private Set<String> normalizeRoles(Collection<String> roles) {
        return roles.stream()
                .filter(Objects::nonNull)
                .map(r -> r.startsWith("ROLE_") ? r : "ROLE_" + r)
                .collect(Collectors.toSet());
    }
}
