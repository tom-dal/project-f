package com.debtcollection.controller;

import com.debtcollection.model.CaseState;
import com.debtcollection.model.DebtCase;
import com.debtcollection.model.StateTransitionConfig;
import com.debtcollection.repository.DebtCaseRepository;
import com.debtcollection.repository.StateTransitionConfigRepository;
import com.debtcollection.service.DebtCaseService;
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

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultHandlers.print;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Integration Test per gli endpoint degli installments
 *
 * Testa:
 * - Creazione di piani rateali
 * - Registrazione di pagamenti per rate
 * - Validazione dei dati di input
 * - Gestione degli errori
 *
 * USER PREFERENCE: Dataset ora inizializzato via DataInitializer MongoDB
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestPropertySource(locations = "classpath:application-test.properties")
public class InstallmentIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DebtCaseRepository debtCaseRepository;

    @Autowired
    private StateTransitionConfigRepository stateTransitionConfigRepository;

    @Autowired
    private DebtCaseService debtCaseService; // USER PREFERENCE: Use service layer instead of repository when loading test data

    @Autowired
    private ObjectMapper objectMapper;

    private String testDebtCaseId;

    @BeforeEach
    void setUp() {
        // USER PREFERENCE: Clean database before each test
        debtCaseRepository.deleteAll();
        stateTransitionConfigRepository.deleteAll();

        // USER PREFERENCE: Create state transition configurations for tests
        createStateTransitionConfigs();

        // Create test debt case using repository - USER PREFERENCE: @Data generates all setters/getters
        DebtCase testCase = new DebtCase();
        testCase.setDebtorName("Test Debtor");
        testCase.setOwedAmount(3000.00); // USER PREFERENCE: Convert BigDecimal to Double for MongoDB
        testCase.setCurrentState(CaseState.MESSA_IN_MORA_DA_FARE);
        testCase.setCurrentStateDate(LocalDateTime.now());
        testCase.setHasInstallmentPlan(false);
        testCase.setPaid(false);
        testCase.setOngoingNegotiations(false);
        // Removed setActive(true)

        DebtCase savedCase = debtCaseRepository.save(testCase);
        testDebtCaseId = savedCase.getId();
    }

    private void createStateTransitionConfigs() {
        // USER PREFERENCE: Create necessary state transition configurations
        StateTransitionConfig config1 = new StateTransitionConfig();
        config1.setFromState(CaseState.MESSA_IN_MORA_DA_FARE);
        config1.setToState(CaseState.DECRETO_INGIUNTIVO_DA_NOTIFICARE);
        config1.setDaysToTransition(30);
        stateTransitionConfigRepository.save(config1);
    }

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void shouldCreateInstallmentPlan() throws Exception {
        // Given
        String requestBody = """
            {
                "numberOfInstallments": 3,
                "firstInstallmentDueDate": "2025-08-01T00:00:00",
                "installmentAmount": "1000.00",
                "frequencyDays": 30
            }
            """;

        // When & Then
        mockMvc.perform(post("/cases/{id}/installment-plan", testDebtCaseId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.installments", hasSize(3)))
                .andExpect(jsonPath("$.installments[0].amount", is(1000.0)))
                .andExpect(jsonPath("$.installments[0].installmentNumber", is(1)))
                .andExpect(jsonPath("$.installments[0].paid", is(false)))
                .andExpect(jsonPath("$.installments[1].installmentNumber", is(2)))
                .andExpect(jsonPath("$.installments[2].installmentNumber", is(3)));
    }

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void shouldValidateInstallmentPlanRequest() throws Exception {
        // Given - Invalid request with missing required fields
        String requestBody = """
            {
                "numberOfInstallments": 0,
                "installmentAmount": -100.00
            }
            """;

        // When & Then
        mockMvc.perform(post("/cases/{id}/installment-plan", testDebtCaseId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andDo(print())
                .andExpect(status().isBadRequest());
    }

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void shouldNotCreateInstallmentPlanForNonExistentCase() throws Exception {
        // Given
        String nonExistentId = "507f1f77bcf86cd799439011";
        String requestBody = """
            {
                "numberOfInstallments": 3,
                "firstInstallmentDueDate": "2025-08-01T00:00:00",
                "installmentAmount": "1000.00",
                "frequencyDays": 30
            }
            """;

        // When & Then
        mockMvc.perform(post("/cases/{id}/installment-plan", nonExistentId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andDo(print())
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", notNullValue()))
                .andExpect(jsonPath("$.error", notNullValue()));
    }

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void shouldRegisterInstallmentPayment() throws Exception {
        // Given - First create an installment plan
        createInstallmentPlanForTest();

        // Get the created installments to find the installment ID
        DebtCase updatedCase = debtCaseRepository.findById(testDebtCaseId).orElseThrow();
        String installmentId = updatedCase.getInstallments().get(0).getInstallmentId();

        String paymentRequest = """
            {
                "amount": "1000.00",
                "paymentDate": "2025-07-28T10:00:00"
            }
            """;

        // When & Then
        mockMvc.perform(post("/cases/{id}/installments/{installmentId}/payments",
                testDebtCaseId, installmentId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(paymentRequest))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.amount", is(1000.0)))
                .andExpect(jsonPath("$.debtCaseId", is(testDebtCaseId)));
    }

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void shouldValidateInstallmentPaymentRequest() throws Exception {
        // Given - Create installment plan first
        createInstallmentPlanForTest();

        DebtCase updatedCase = debtCaseRepository.findById(testDebtCaseId).orElseThrow();
        String installmentId = updatedCase.getInstallments().get(0).getInstallmentId();

        // Invalid payment request with negative amount
        String paymentRequest = """
            {
                "amount": -100.00,
                "paymentDate": "2025-07-28T10:00:00"
            }
            """;

        // When & Then
        mockMvc.perform(post("/cases/{id}/installments/{installmentId}/payments",
                testDebtCaseId, installmentId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(paymentRequest))
                .andDo(print())
                .andExpect(status().isBadRequest());
    }

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void shouldNotRegisterPaymentForNonExistentInstallment() throws Exception {
        // Given
        String nonExistentInstallmentId = "non-existent-id";
        String paymentRequest = """
            {
                "amount": "1000.00",
                "paymentDate": "2025-07-28T10:00:00"
            }
            """;

        // When & Then
        mockMvc.perform(post("/cases/{id}/installments/{installmentId}/payments",
                testDebtCaseId, nonExistentInstallmentId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(paymentRequest))
                .andDo(print())
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", notNullValue()))
                .andExpect(jsonPath("$.error", notNullValue()));
    }

    @Test
    @WithMockUser(username = "admin", roles = {"ADMIN"})
    void shouldNotCreateDuplicateInstallmentPlan() throws Exception {
        // Given - Create first installment plan
        createInstallmentPlanForTest();

        // Try to create another installment plan for the same case
        String requestBody = """
            {
                "numberOfInstallments": 2,
                "firstInstallmentDueDate": "2025-09-01T00:00:00",
                "installmentAmount": "1500.00",
                "frequencyDays": 30
            }
            """;

        // When & Then
        mockMvc.perform(post("/cases/{id}/installment-plan", testDebtCaseId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andDo(print())
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", notNullValue()))
                .andExpect(jsonPath("$.error", notNullValue()));
    }

    // USER PREFERENCE: Helper method to create installment plan for tests
    private void createInstallmentPlanForTest() throws Exception {
        String requestBody = """
            {
                "numberOfInstallments": 3,
                "firstInstallmentDueDate": "2025-08-01T00:00:00",
                "installmentAmount": "1000.00",
                "frequencyDays": 30
            }
            """;

        mockMvc.perform(post("/cases/{id}/installment-plan", testDebtCaseId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isOk());
    }
}
