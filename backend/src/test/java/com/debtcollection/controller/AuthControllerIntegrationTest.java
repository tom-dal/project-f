package com.debtcollection.controller;

import com.debtcollection.DebtCollectionApplication;
import com.debtcollection.model.User;
import com.debtcollection.repository.UserRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.Map;
import java.util.Set;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(classes = DebtCollectionApplication.class)
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestPropertySource(locations = "classpath:application-test.properties")
class AuthControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @BeforeEach
    void setUp() {
        // USER PREFERENCE: Clean database and create admin user for tests
        userRepository.deleteAll();

        // Wait for delete to complete
        try {
            Thread.sleep(100);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        // Create admin user with expected credentials
        User adminUser = new User();
        adminUser.setUsername("admin");
        adminUser.setPassword(passwordEncoder.encode("admin"));
        adminUser.setPasswordExpired(true);
        adminUser.setRoles(Set.of("ROLE_ADMIN"));

        User savedUser = userRepository.save(adminUser);

        // Verify user was created
        if (savedUser == null || savedUser.getId() == null) {
            throw new RuntimeException("Failed to create admin user for test");
        }

        // Double-check user exists
        boolean userExists = userRepository.findByUsername("admin").isPresent();
        if (!userExists) {
            throw new RuntimeException("Admin user not found after creation");
        }
    }

    @Test
    void testLogin_Success() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per login con credenziali valide
        String loginRequest = """
            {
                "username": "admin",
                "password": "admin"
            }
            """;

        mockMvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginRequest))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.token").exists())
                .andExpect(jsonPath("$.passwordExpired").value(true)); // Default admin ha password scaduta
    }

    @Test
    void testLogin_InvalidCredentials() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per login con credenziali invalide
        String loginRequest = """
            {
                "username": "admin",
                "password": "wrongpassword"
            }
            """;

        mockMvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginRequest))
                .andExpect(status().isUnauthorized())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.error").exists())
                .andExpect(jsonPath("$.message").exists());
    }

    @Test
    void testLogin_MissingUsername() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per login con username mancante
        String loginRequest = """
            {
                "password": "admin"
            }
            """;

        mockMvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginRequest))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void testLogin_MissingPassword() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per login con password mancante
        String loginRequest = """
            {
                "username": "admin"
            }
            """;

        mockMvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginRequest))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void testLogin_EmptyBody() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per login con body vuoto
        mockMvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void testChangePassword_Success() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per cambio password con token reale
        // Prima otteniamo un token reale
        String loginRequest = """
            {
                "username": "admin",
                "password": "admin"
            }
            """;

        MvcResult loginResult = mockMvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginRequest))
                .andExpect(status().isOk())
                .andReturn();

        String responseContent = loginResult.getResponse().getContentAsString();
        Map<String, Object> responseMap = objectMapper.readValue(responseContent, new TypeReference<Map<String, Object>>(){});
        String token = (String) responseMap.get("token");

        // Ora testiamo il cambio password con il token limitato
        String changePasswordRequest = """
            {
                "oldPassword": "admin",
                "newPassword": "Admin123!"
            }
            """;

        mockMvc.perform(post("/auth/change-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(changePasswordRequest)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.token").exists())
                .andExpect(jsonPath("$.passwordExpired").value(false)); // Dopo cambio password non è più scaduta
    }

    @Test
    void testChangePassword_WrongOldPassword() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per cambio password con vecchia password sbagliata
        // Prima otteniamo un token reale
        String loginRequest = """
            {
                "username": "admin",
                "password": "admin"
            }
            """;

        MvcResult loginResult = mockMvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginRequest))
                .andExpect(status().isOk())
                .andReturn();

        String responseContent = loginResult.getResponse().getContentAsString();
        Map<String, Object> responseMap = objectMapper.readValue(responseContent, new TypeReference<Map<String, Object>>(){});
        String token = (String) responseMap.get("token");

        String changePasswordRequest = """
            {
                "oldPassword": "wrongpassword",
                "newPassword": "Admin123!"
            }
            """;

        mockMvc.perform(post("/auth/change-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(changePasswordRequest)
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isInternalServerError()); // Exception nel service
    }

    @Test
    void testChangePassword_WithoutAuthentication() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per cambio password senza autenticazione
        String changePasswordRequest = """
            {
                "oldPassword": "admin",
                "newPassword": "Admin123!"
            }
            """;

        mockMvc.perform(post("/auth/change-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(changePasswordRequest))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void testValidateToken_ValidToken() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per validazione token valido con token completo
        // Prima otteniamo un token limitato
        String loginRequest = """
            {
                "username": "admin",
                "password": "admin"
            }
            """;

        MvcResult loginResult = mockMvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginRequest))
                .andExpect(status().isOk())
                .andReturn();

        String responseContent = loginResult.getResponse().getContentAsString();
        Map<String, Object> responseMap = objectMapper.readValue(responseContent, new TypeReference<Map<String, Object>>(){});
        String limitedToken = (String) responseMap.get("token");

        // Cambiamo la password per ottenere un token completo
        String changePasswordRequest = """
            {
                "oldPassword": "admin",
                "newPassword": "Admin123!"
            }
            """;

        MvcResult changePasswordResult = mockMvc.perform(post("/auth/change-password")
                .contentType(MediaType.APPLICATION_JSON)
                .content(changePasswordRequest)
                .header("Authorization", "Bearer " + limitedToken))
                .andExpect(status().isOk())
                .andReturn();

        String changePasswordResponseContent = changePasswordResult.getResponse().getContentAsString();
        Map<String, Object> changePasswordResponseMap = objectMapper.readValue(changePasswordResponseContent, new TypeReference<Map<String, Object>>(){});
        String fullToken = (String) changePasswordResponseMap.get("token");

        // Ora testiamo la validazione con il token completo
        mockMvc.perform(get("/auth/validate")
                .header("Authorization", "Bearer " + fullToken))
                .andExpect(status().isOk());
    }

    @Test
    void testValidateToken_InvalidToken() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per validazione token invalido
        mockMvc.perform(get("/auth/validate")
                .header("Authorization", "Bearer invalidtoken"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void testValidateToken_MissingHeader() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per validazione senza header Authorization
        // L'endpoint ha @RequestHeader obbligatorio, quindi restituisce 500 (non 401)
        mockMvc.perform(get("/auth/validate"))
                .andExpect(status().isInternalServerError()); // 500 perché manca parametro obbligatorio
    }

    @Test
    void testValidateToken_MalformedHeader() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per validazione con header malformato
        mockMvc.perform(get("/auth/validate")
                .header("Authorization", "InvalidFormat"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(username = "admin")
    void testTestPasswordHash() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per endpoint di test hash password
        // Questo endpoint richiede autenticazione, usiamo @WithMockUser
        mockMvc.perform(get("/auth/test-password/testpassword"))
                .andExpect(status().isOk())
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Hash:")))
                .andExpect(content().string(org.hamcrest.Matchers.containsString("Matches: true")));
    }
}
