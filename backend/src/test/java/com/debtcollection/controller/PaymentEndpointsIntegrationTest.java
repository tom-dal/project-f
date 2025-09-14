package com.debtcollection.controller;

import com.debtcollection.dto.DebtCaseDto;
import com.debtcollection.model.CaseState;
import com.debtcollection.service.DebtCaseService;
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
import org.springframework.test.web.servlet.MvcResult;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultHandlers.print;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Integration tests for payment management endpoints on /cases/{id}/payments
 * USER PREFERENCE: Monetary amounts via BigDecimal in API, Double in model.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestPropertySource(locations = "classpath:application-test.properties")
public class PaymentEndpointsIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DebtCaseService debtCaseService;

    private String caseId;

    @BeforeEach
    void initCase() {
        // Create a fresh debt case using the service layer (test data policy)
        DebtCaseDto dto = debtCaseService.createDebtCase(
                "Pagamenti Test", CaseState.MESSA_IN_MORA_DA_FARE, LocalDateTime.now(), new BigDecimal("150.00")
        );
        caseId = dto.getId();
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void fullPaymentLifecycle() throws Exception {
        // 1. Register payment
        MvcResult registerResult = mockMvc.perform(post("/cases/" + caseId + "/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"amount\":50.00,\"paymentDate\":\"2025-01-01T10:00:00\"}"))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.amount", is(50.00)))
                .andExpect(jsonPath("$.debtCaseId", is(caseId)))
                .andExpect(jsonPath("$.id", notNullValue()))
                .andReturn();

        String responseBody = registerResult.getResponse().getContentAsString();
        String paymentId = extractJsonValue(responseBody, "id");

        // 2. List payments
        mockMvc.perform(get("/cases/" + caseId + "/payments"))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].id", is(paymentId)))
                .andExpect(jsonPath("$[0].amount", is(50.00)));

        // 3. Update payment (amount + date)
        mockMvc.perform(put("/cases/" + caseId + "/payments/" + paymentId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"amount\":75.50,\"paymentDate\":\"2025-02-02\"}"))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id", is(paymentId)))
                .andExpect(jsonPath("$.amount", is(75.50)))
                .andExpect(jsonPath("$.paymentDate", is("2025-02-02")));

        // 4. Delete payment
        mockMvc.perform(delete("/cases/" + caseId + "/payments/" + paymentId))
                .andDo(print())
                .andExpect(status().isNoContent());

        // 5. List again -> empty
        mockMvc.perform(get("/cases/" + caseId + "/payments"))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(0)));
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void paymentCompletesCase() throws Exception {
        // Case owed = 150. Register payment 150 -> case should become COMPLETATA & paid=true
        mockMvc.perform(post("/cases/" + caseId + "/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"amount\":150.00}"))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.amount", is(150.00)));

        // Fetch case details (API uses 'state' field, not 'currentState')
        mockMvc.perform(get("/cases/" + caseId))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.state", is("COMPLETATA")))
                .andExpect(jsonPath("$.paid", is(true)))
                .andExpect(jsonPath("$.nextDeadlineDate", nullValue()));
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void invalidPaymentAmountReturnsBadRequest() throws Exception {
        mockMvc.perform(post("/cases/" + caseId + "/payments")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"amount\":0}"))
                .andDo(print())
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("greater than zero")));
    }

    // Simple JSON value extractor (lightweight, avoids pulling full JSON parser in test)
    private String extractJsonValue(String json, String field) {
        // naive extraction for pattern "field":"value" OR "field":value
        int idx = json.indexOf("\"" + field + "\"");
        if (idx < 0) return null;
        int colon = json.indexOf(":", idx);
        if (colon < 0) return null;
        int startQuote = json.indexOf('"', colon + 1);
        int endQuote = -1;
        if (startQuote > 0) {
            endQuote = json.indexOf('"', startQuote + 1);
        }
        if (startQuote > 0 && endQuote > startQuote) {
            return json.substring(startQuote + 1, endQuote);
        }
        // numeric fallback
        String tail = json.substring(colon + 1).trim();
        int end = 0;
        while (end < tail.length() && "0123456789.-".indexOf(tail.charAt(end)) >= 0) end++;
        return tail.substring(0, end);
    }
}
