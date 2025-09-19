package com.debtcollection.controller;

import com.debtcollection.dto.UserCreateRequest;
import com.debtcollection.dto.UserUpdateRequest;
import com.debtcollection.model.User;
import com.debtcollection.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Profile;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.List;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class UserControllerIntegrationTest {
    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private UserRepository userRepository;
    @Autowired
    private ObjectMapper objectMapper;

    @BeforeEach
    void setup() {
        userRepository.deleteAll();
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void getAllUsers_returnsEmptyListInitially() throws Exception {
        mockMvc.perform(get("/users"))
                .andExpect(status().isOk())
                .andExpect(content().json("[]"));
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void createUser_andGetAllUsers() throws Exception {
        UserCreateRequest req = new UserCreateRequest();
        req.setUsername("testuser");
        req.setPassword("Admin123!");
        req.setRoles(List.of("ADMIN"));
        req.setPasswordExpired(false);

        mockMvc.perform(post("/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("testuser"))
                .andExpect(jsonPath("$.roles[0]").value("ADMIN"));

        mockMvc.perform(get("/users"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].username").value("testuser"));
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void updateUser_changesUsernameAndPasswordExpired() throws Exception {
        User user = new User();
        user.setUsername("olduser");
        user.setPassword("encoded");
        user.setRoles(Set.of("ADMIN"));
        user.setPasswordExpired(false);
        user = userRepository.save(user);

        UserUpdateRequest update = new UserUpdateRequest();
        update.setUsername("newuser");
        update.setPasswordExpired(true);

        mockMvc.perform(put("/users/" + user.getId())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(update)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("newuser"))
                .andExpect(jsonPath("$.passwordExpired").value(true));
    }

    @Test
    @WithMockUser(roles = "ADMIN")
    void deleteUser_removesUser() throws Exception {
        User user = new User();
        user.setUsername("todelete");
        user.setPassword("encoded");
        user.setRoles(Set.of("ADMIN"));
        user.setPasswordExpired(false);
        user = userRepository.save(user);

        mockMvc.perform(delete("/users/" + user.getId()))
                .andExpect(status().isOk());

        assertThat(userRepository.findById(user.getId())).isEmpty();
    }

    @Test
    @WithMockUser(roles = "USER")
    void endpoints_forbiddenForNonAdmin() throws Exception {
        mockMvc.perform(get("/users"))
                .andExpect(status().isForbidden());
        mockMvc.perform(post("/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
                .andExpect(status().isForbidden());
        mockMvc.perform(put("/users/123")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{}"))
                .andExpect(status().isForbidden());
        mockMvc.perform(delete("/users/123"))
                .andExpect(status().isForbidden());
    }
}

