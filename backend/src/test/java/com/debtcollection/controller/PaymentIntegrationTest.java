package com.debtcollection.controller;


import com.debtcollection.model.CaseState;
import com.debtcollection.model.DebtCase;
import com.debtcollection.repository.DebtCaseRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@WithMockUser(username = "testuser", roles = "USER") 
@ActiveProfiles("test")
@TestPropertySource(locations = "classpath:application-test.properties")
class PaymentIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DebtCaseRepository debtCaseRepository;

    @Autowired
    private ObjectMapper objectMapper;

    private DebtCase testDebtCase;

    @BeforeEach
    void setUp() {
        // USER PREFERENCE: Clean MongoDB collections for each test
        debtCaseRepository.deleteAll();

        // Create test debt case
        testDebtCase = new DebtCase();
        testDebtCase.setDebtorName("Test Debtor");
        testDebtCase.setOwedAmount(1000.00); // USER PREFERENCE: Convert BigDecimal to Double for MongoDB
        // CUSTOM IMPLEMENTATION: Set direct state fields instead of CaseHistory
        testDebtCase.setCurrentState(CaseState.MESSA_IN_MORA_DA_FARE);
        testDebtCase.setCurrentStateDate(LocalDateTime.now());
        testDebtCase.setHasInstallmentPlan(false);
        testDebtCase.setPaid(false);
        testDebtCase.setOngoingNegotiations(false);
        testDebtCase = debtCaseRepository.save(testDebtCase);
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void registerPayment_ShouldCreatePayment() throws Exception {
        // Given
        DebtCaseController.RegisterPaymentRequest request = 
            new DebtCaseController.RegisterPaymentRequest(
                new BigDecimal("500.00"), // USER PREFERENCE: Use BigDecimal for DTO/API layer
                LocalDateTime.now()
            );

        // When & Then
        mockMvc.perform(post("/cases/{id}/payments", testDebtCase.getId())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.amount").value(500.0))
                .andExpect(jsonPath("$.debtCaseId").value(testDebtCase.getId()));
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void registerPayment_ShouldMarkCaseAsCompleted_WhenFullyPaid() throws Exception {
        // Given - payment for full amount
        DebtCaseController.RegisterPaymentRequest request = 
            new DebtCaseController.RegisterPaymentRequest(
                new BigDecimal("1000.00"), // USER PREFERENCE: Use BigDecimal for DTO/API layer
                LocalDateTime.now()
            );

        // When
        mockMvc.perform(post("/cases/{id}/payments", testDebtCase.getId())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk());

        // Then - verify case state changed to COMPLETED
        DebtCase updatedCase = debtCaseRepository.findById(testDebtCase.getId()).orElseThrow();
        assert updatedCase.getCurrentState() == CaseState.COMPLETATA;
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void registerPayment_ShouldReturn400_WhenInvalidAmount() throws Exception {
        // Given
        DebtCaseController.RegisterPaymentRequest request = 
            new DebtCaseController.RegisterPaymentRequest(
                new BigDecimal("0.00"),  // Invalid amount
                LocalDateTime.now()
            );

        // When & Then
        mockMvc.perform(post("/cases/{id}/payments", testDebtCase.getId())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest()); // Should be 400 with proper error handling
    }
}
