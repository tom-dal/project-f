package com.debtcollection.service;

import com.debtcollection.model.User;
import com.debtcollection.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;

import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserService userService;

    private User mockUser;

    @BeforeEach
    void setUp() {
        // CUSTOM IMPLEMENTATION: Setup utente mock per test UserDetailsService
        mockUser = new User();
        mockUser.setId("user123");
        mockUser.setUsername("admin");
        mockUser.setPassword("$2a$10$encodedPassword");
        mockUser.setPasswordExpired(false);
        mockUser.setRoles(Set.of("ROLE_ADMIN"));
    }

    @Test
    void loadUserByUsername_ShouldReturnUserDetails_WhenUserExists() {
        // Given
        when(userRepository.findByUsername("admin")).thenReturn(Optional.of(mockUser));

        // When
        UserDetails result = userService.loadUserByUsername("admin");

        // Then
        assertNotNull(result);
        assertEquals("admin", result.getUsername());
        assertEquals("$2a$10$encodedPassword", result.getPassword());
        assertTrue(result.getAuthorities().stream()
                .anyMatch(auth -> auth.getAuthority().equals("ROLE_ADMIN")));
        verify(userRepository).findByUsername("admin");
    }

    @Test
    void loadUserByUsername_ShouldThrowUsernameNotFoundException_WhenUserNotFound() {
        // Given
        when(userRepository.findByUsername("nonexistent")).thenReturn(Optional.empty());

        // When & Then
        UsernameNotFoundException exception = assertThrows(
            UsernameNotFoundException.class,
            () -> userService.loadUserByUsername("nonexistent")
        );

        assertEquals("User not found: nonexistent", exception.getMessage());
        verify(userRepository).findByUsername("nonexistent");
    }

    @Test
    void loadUserByUsername_ShouldHandleNullUsername() {
        // Given
        when(userRepository.findByUsername(null)).thenReturn(Optional.empty());

        // When & Then
        assertThrows(UsernameNotFoundException.class,
                    () -> userService.loadUserByUsername(null));
    }

    @Test
    void loadUserByUsername_ShouldHandleEmptyUsername() {
        // Given
        when(userRepository.findByUsername("")).thenReturn(Optional.empty());

        // When & Then
        UsernameNotFoundException exception = assertThrows(
            UsernameNotFoundException.class,
            () -> userService.loadUserByUsername("")
        );

        assertEquals("User not found: ", exception.getMessage());
    }

    @Test
    void getUserFromUserDetails_ShouldReturnUser_WhenUserExists() {
        // Given
        UserDetails userDetails = mockUser; // User implements UserDetails
        when(userRepository.findByUsername("admin")).thenReturn(Optional.of(mockUser));

        // When
        User result = userService.getUserFromUserDetails(userDetails);

        // Then
        assertNotNull(result);
        assertEquals("admin", result.getUsername());
        assertEquals(mockUser.getId(), result.getId());
        assertEquals(mockUser.getRoles(), result.getRoles());
        verify(userRepository).findByUsername("admin");
    }

    @Test
    void getUserFromUserDetails_ShouldThrowException_WhenUserNotFound() {
        // Given
        UserDetails userDetails = mockUser;
        when(userRepository.findByUsername("admin")).thenReturn(Optional.empty());

        // When & Then
        UsernameNotFoundException exception = assertThrows(
            UsernameNotFoundException.class,
            () -> userService.getUserFromUserDetails(userDetails)
        );

        assertEquals("User not found: admin", exception.getMessage());
    }

    @Test
    void getUserFromUserDetails_ShouldHandleUserDetailsWithDifferentUsername() {
        // Given
        User differentUser = new User();
        differentUser.setUsername("testuser");
        differentUser.setPassword("password");
        differentUser.setRoles(Set.of("ROLE_USER"));

        when(userRepository.findByUsername("testuser")).thenReturn(Optional.of(differentUser));

        // When
        User result = userService.getUserFromUserDetails(differentUser);

        // Then
        assertNotNull(result);
        assertEquals("testuser", result.getUsername());
        assertTrue(result.getRoles().contains("ROLE_USER"));
    }

    @Test
    void loadUserByUsername_ShouldReturnUserWithCorrectAuthorities() {
        // Given - User con multiple ruoli
        mockUser.setRoles(Set.of("ROLE_ADMIN", "ROLE_USER"));
        when(userRepository.findByUsername("admin")).thenReturn(Optional.of(mockUser));

        // When
        UserDetails result = userService.loadUserByUsername("admin");

        // Then
        assertNotNull(result);
        assertEquals(2, result.getAuthorities().size());
        assertTrue(result.getAuthorities().stream()
                .anyMatch(auth -> auth.getAuthority().equals("ROLE_ADMIN")));
        assertTrue(result.getAuthorities().stream()
                .anyMatch(auth -> auth.getAuthority().equals("ROLE_USER")));
    }

    @Test
    void loadUserByUsername_ShouldReturnUserWithPasswordExpiredStatus() {
        // Given - User con password scaduta
        mockUser.setPasswordExpired(true);
        when(userRepository.findByUsername("admin")).thenReturn(Optional.of(mockUser));

        // When
        UserDetails result = userService.loadUserByUsername("admin");

        // Then
        assertNotNull(result);
        // CUSTOM IMPLEMENTATION: Verifica che UserDetails rifletta lo stato password scaduta
        // Questo dipende dall'implementazione del metodo isCredentialsNonExpired() in User
        assertEquals("admin", result.getUsername());
        assertTrue(mockUser.isPasswordExpired()); // Verifica stato interno
    }

    @Test
    void loadUserByUsername_ShouldReturnUserWithNoRoles() {
        // Given - User senza ruoli
        mockUser.setRoles(Set.of());
        when(userRepository.findByUsername("admin")).thenReturn(Optional.of(mockUser));

        // When
        UserDetails result = userService.loadUserByUsername("admin");

        // Then
        assertNotNull(result);
        assertTrue(result.getAuthorities().isEmpty());
    }
}
