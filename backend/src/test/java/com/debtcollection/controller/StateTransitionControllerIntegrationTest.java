package com.debtcollection.controller;

import com.debtcollection.DebtCollectionApplication;
import com.debtcollection.model.CaseState;
import com.debtcollection.model.StateTransitionConfig;
import com.debtcollection.model.User;
import com.debtcollection.repository.StateTransitionConfigRepository;
import com.debtcollection.repository.UserRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.With;
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

import java.util.*;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(classes = DebtCollectionApplication.class)
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestPropertySource(locations = "classpath:application-test.properties")
class StateTransitionControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private StateTransitionConfigRepository configRepository;

    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
        // sleep to ensure delete flush (pattern used elsewhere)
        try { Thread.sleep(50);} catch (InterruptedException e){ Thread.currentThread().interrupt(); }
        User adminUser = new User();
        adminUser.setUsername("admin");
        adminUser.setPassword(passwordEncoder.encode("admin"));
        adminUser.setPasswordExpired(true); // forza change-password flow
        adminUser.setRoles(Set.of("ADMIN"));
        userRepository.save(adminUser);
    }

    private String obtainFullAdminToken() throws Exception {
        // 1. Login (limited token)
        String loginBody = """
            {"username":"admin","password":"admin"}
            """;
        MvcResult loginResult = mockMvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginBody))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.passwordExpired").value(true))
            .andReturn();
        Map<String,Object> loginMap = objectMapper.readValue(loginResult.getResponse().getContentAsString(), new TypeReference<>(){});
        String limitedToken = (String) loginMap.get("token");

        // 2. Change password (full token)
        String changeBody = """
            {"oldPassword":"admin","newPassword":"Admin123!"}
            """;
        MvcResult changeResult = mockMvc.perform(post("/auth/change-password")
                .contentType(MediaType.APPLICATION_JSON)
                .header("Authorization", "Bearer " + limitedToken)
                .content(changeBody))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.passwordExpired").value(false))
            .andReturn();
        Map<String,Object> changeMap = objectMapper.readValue(changeResult.getResponse().getContentAsString(), new TypeReference<>(){});
        return (String) changeMap.get("token");
    }

    @Test
    void testGetTransitions_AsAdmin_Success() throws Exception {
        String token = obtainFullAdminToken();
        mockMvc.perform(get("/state-transitions")
                .header("Authorization", "Bearer " + token))
            .andExpect(status().isOk())
            .andExpect(content().contentType(MediaType.APPLICATION_JSON));
    }

    @Test
    void testGetTransitions_WithPasswordChangeToken_Forbidden() throws Exception {
        // Only perform login (limited token) and use it directly
        String loginBody = """
            {"username":"admin","password":"admin"}
            """;
        MvcResult loginResult = mockMvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(loginBody))
            .andExpect(status().isOk())
            .andReturn();
        Map<String,Object> loginMap = objectMapper.readValue(loginResult.getResponse().getContentAsString(), new TypeReference<>(){});
        String limitedToken = (String) loginMap.get("token");

        mockMvc.perform(get("/state-transitions")
                .header("Authorization", "Bearer " + limitedToken))
            .andExpect(status().isForbidden()); // password change token non valido per endpoint
    }

    @Test
    void testUpdateTransition_DaysChanged() throws Exception {
        String token = obtainFullAdminToken();
        List<StateTransitionConfig> configs = configRepository.findAll();
        assertThat(configs).isNotEmpty();
        StateTransitionConfig first = configs.get(0);
        Integer originalDays = first.getDaysToTransition();
        int newDays = originalDays + 1;

        String body = objectMapper.writeValueAsString(List.of(Map.of(
            "fromState", first.getFromState().name(),
            "daysToTransition", newDays
        )));

        MvcResult result = mockMvc.perform(put("/state-transitions")
                .contentType(MediaType.APPLICATION_JSON)
                .header("Authorization", "Bearer " + token)
                .content(body))
            .andExpect(status().isOk())
            .andReturn();

        // Verify response contains updated days
        List<Map<String,Object>> responseList = objectMapper.readValue(result.getResponse().getContentAsString(), new TypeReference<>(){});
        Map<String,Object> updatedEntry = responseList.stream()
            .filter(m -> Objects.equals(m.get("fromState"), first.getFromState().name()))
            .findFirst().orElseThrow();
        assertThat(updatedEntry.get("daysToTransition")).isEqualTo(newDays);
    }

    @Test
    void testUpdateTransition_InvalidDays_BadRequest() throws Exception {
        String token = obtainFullAdminToken();
        StateTransitionConfig any = configRepository.findAll().get(0);
        String body = objectMapper.writeValueAsString(List.of(Map.of(
            "fromState", any.getFromState().name(),
            "daysToTransition", 0 // invalid
        )));
        mockMvc.perform(put("/state-transitions")
                .contentType(MediaType.APPLICATION_JSON)
                .header("Authorization", "Bearer " + token)
                .content(body))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.error").value("IllegalArgumentException"));
    }
}

