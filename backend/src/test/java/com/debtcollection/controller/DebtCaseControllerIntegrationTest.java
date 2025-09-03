package com.debtcollection.controller;


import com.debtcollection.model.CaseState;
import com.debtcollection.model.DebtCase;
import com.debtcollection.model.StateTransitionConfig;
import com.debtcollection.repository.DebtCaseRepository;
import com.debtcollection.repository.StateTransitionConfigRepository;
import com.debtcollection.service.DebtCaseService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.hateoas.MediaTypes;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultHandlers.print;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Integration Test per l'endpoint /cases
 * 
 * Testa:
 * - Restituzione di tutti i casi senza filtri
 * - Filtri per nome debitore
 * - Filtri per stato
 * - Filtri per range di importo
 * - Filtri per range di date
 * - Combinazione di filtri multipli
 * 
 * USER PREFERENCE: Tests updated to support HATEOAS response format and MongoDB
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestPropertySource(locations = "classpath:application-test.properties")
public class DebtCaseControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DebtCaseRepository debtCaseRepository;

    @Autowired
    private StateTransitionConfigRepository stateTransitionConfigRepository;

    @Autowired
    private DebtCaseService debtCaseService;

    @BeforeEach
    void setUp() {
        debtCaseRepository.deleteAll();
        stateTransitionConfigRepository.deleteAll();

        // USER PREFERENCE: Create state transition configurations for tests
        createStateTransitionConfigs();

        // Wait for deletion to complete - increased wait time for MongoDB
        try {
            Thread.sleep(50);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        // USER PREFERENCE: Create test data directly via repository to bypass state machine validation in tests
        // Caso 1: Mario Rossi, importo 1000, stato MESSA_IN_MORA_DA_FARE
        DebtCase case1 = new DebtCase();
        case1.setDebtorName("Mario Rossi");
        case1.setOwedAmount(1000.00); // USER PREFERENCE: Convert BigDecimal to Double for MongoDB
        case1.setCurrentState(CaseState.MESSA_IN_MORA_DA_FARE);
        case1.setCurrentStateDate(LocalDateTime.now());
        case1.setHasInstallmentPlan(false);
        case1.setPaid(false);
        case1.setOngoingNegotiations(false);
        DebtCase savedCase1 = debtCaseRepository.save(case1);

        // Caso 2: Luigi Verdi, importo 2500, stato DEPOSITO_RICORSO
        DebtCase case2 = new DebtCase();
        case2.setDebtorName("Luigi Verdi");
        case2.setOwedAmount(2500.00); // USER PREFERENCE: Convert BigDecimal to Double for MongoDB
        case2.setCurrentState(CaseState.DEPOSITO_RICORSO);
        case2.setCurrentStateDate(LocalDateTime.now());
        case2.setHasInstallmentPlan(false);
        case2.setPaid(false);
        case2.setOngoingNegotiations(false);
        DebtCase savedCase2 = debtCaseRepository.save(case2);

        // Caso 3: Anna Bianchi, importo 500, stato COMPLETATA (ma non pagata)
        DebtCase case3 = new DebtCase();
        case3.setDebtorName("Anna Bianchi");
        case3.setOwedAmount(500.00); // USER PREFERENCE: Convert BigDecimal to Double for MongoDB
        case3.setCurrentState(CaseState.COMPLETATA);
        case3.setCurrentStateDate(LocalDateTime.now());
        case3.setHasInstallmentPlan(false);
        case3.setPaid(false); // USER PREFERENCE: Changed to false to avoid validation error without payments
        case3.setOngoingNegotiations(false);
        DebtCase savedCase3 = debtCaseRepository.save(case3);

        // Caso 4: Gianni Neri, importo 3000, stato MESSA_IN_MORA_DA_FARE
        DebtCase case4 = new DebtCase();
        case4.setDebtorName("Gianni Neri");
        case4.setOwedAmount(3000.00); // USER PREFERENCE: Convert BigDecimal to Double for MongoDB
        case4.setCurrentState(CaseState.MESSA_IN_MORA_DA_FARE);
        case4.setCurrentStateDate(LocalDateTime.now());
        case4.setHasInstallmentPlan(false);
        case4.setPaid(false);
        case4.setOngoingNegotiations(false);
        DebtCase savedCase4 = debtCaseRepository.save(case4);

        // USER PREFERENCE: Force MongoDB to flush changes and wait for persistence
        try {
            Thread.sleep(300);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        // USER PREFERENCE: Verify all test cases were created correctly
        long totalCases = debtCaseRepository.count();
        if (totalCases != 4) {
            throw new RuntimeException("Expected 4 test cases, but found: " + totalCases);
        }

        // Verify specific cases exist with exact amounts for range filter test
        boolean marioCaseExists = debtCaseRepository.findAll().stream()
                .anyMatch(c -> "Mario Rossi".equals(c.getDebtorName()) &&
                              c.getOwedAmount().equals(1000.00)); // USER PREFERENCE: Compare Double values for MongoDB
        boolean luigiCaseExists = debtCaseRepository.findAll().stream()
                .anyMatch(c -> "Luigi Verdi".equals(c.getDebtorName()) &&
                              c.getOwedAmount().equals(2500.00)); // USER PREFERENCE: Compare Double values for MongoDB

        if (!marioCaseExists) {
            throw new RuntimeException("Mario Rossi case not found with amount 1000.00");
        }
        if (!luigiCaseExists) {
            throw new RuntimeException("Luigi Verdi case not found with amount 2500.00");
        }

        // Additional verification: check that cases in range 1000-2500 are exactly 2
        long casesInRange = debtCaseRepository.findAll().stream()
                .filter(c -> c.getOwedAmount() >= 1000.00 && c.getOwedAmount() <= 2500.00) // USER PREFERENCE: Compare Double values directly for MongoDB
                .count();
        if (casesInRange != 2) {
            throw new RuntimeException("Expected 2 cases in range 1000-2500, but found: " + casesInRange);
        }
    }

    private void createStateTransitionConfigs() {
        // Create all necessary state transition configurations for tests
        StateTransitionConfig config1 = new StateTransitionConfig();
        config1.setFromState(CaseState.MESSA_IN_MORA_DA_FARE);
        config1.setToState(CaseState.DECRETO_INGIUNTIVO_DA_NOTIFICARE);
        config1.setDaysToTransition(30);
        stateTransitionConfigRepository.save(config1);

        StateTransitionConfig config2 = new StateTransitionConfig();
        config2.setFromState(CaseState.DECRETO_INGIUNTIVO_DA_NOTIFICARE);
        config2.setToState(CaseState.DECRETO_INGIUNTIVO_NOTIFICATO);
        config2.setDaysToTransition(10);
        stateTransitionConfigRepository.save(config2);

        StateTransitionConfig config3 = new StateTransitionConfig();
        config3.setFromState(CaseState.DECRETO_INGIUNTIVO_NOTIFICATO);
        config3.setToState(CaseState.PRECETTO);
        config3.setDaysToTransition(40);
        stateTransitionConfigRepository.save(config3);

        StateTransitionConfig config4 = new StateTransitionConfig();
        config4.setFromState(CaseState.PRECETTO);
        config4.setToState(CaseState.PIGNORAMENTO);
        config4.setDaysToTransition(10);
        stateTransitionConfigRepository.save(config4);

        StateTransitionConfig config5 = new StateTransitionConfig();
        config5.setFromState(CaseState.PIGNORAMENTO);
        config5.setToState(CaseState.DEPOSITO_RICORSO);
        config5.setDaysToTransition(30);
        stateTransitionConfigRepository.save(config5);

        StateTransitionConfig config6 = new StateTransitionConfig();
        config6.setFromState(CaseState.DEPOSITO_RICORSO);
        config6.setToState(CaseState.COMPLETATA);
        config6.setDaysToTransition(90);
        stateTransitionConfigRepository.save(config6);
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testGetAllCasesWithoutFilters() throws Exception {
        mockMvc.perform(get("/cases")
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaTypes.HAL_JSON))
                .andExpect(jsonPath("$._embedded.cases", hasSize(4)))
                .andExpect(jsonPath("$._embedded.cases[*].debtorName", containsInAnyOrder(
                        "Mario Rossi", "Luigi Verdi", "Anna Bianchi", "Gianni Neri")))
                .andExpect(jsonPath("$.page.totalElements", is(4)));
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testFilterByDebtorName() throws Exception {
        mockMvc.perform(get("/cases")
                .param("debtorName", "Mario")
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaTypes.HAL_JSON))
                .andExpect(jsonPath("$._embedded.cases", hasSize(1)))
                .andExpect(jsonPath("$._embedded.cases[0].debtorName", is("Mario Rossi")))
                .andExpect(jsonPath("$.page.totalElements", is(1)));
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testFilterByState() throws Exception {
        mockMvc.perform(get("/cases")
                .param("state", "MESSA_IN_MORA_DA_FARE")
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaTypes.HAL_JSON))
                .andExpect(jsonPath("$._embedded.cases", hasSize(2)))
                .andExpect(jsonPath("$._embedded.cases[*].debtorName", containsInAnyOrder("Mario Rossi", "Gianni Neri")))
                .andExpect(jsonPath("$.page.totalElements", is(2)));
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testFilterByAmountRange() throws Exception {
        mockMvc.perform(get("/cases")
                .param("minAmount", "1000.00")  // USER PREFERENCE: Explicit decimal format
                .param("maxAmount", "2500.00")  // USER PREFERENCE: Explicit decimal format
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaTypes.HAL_JSON))
                .andExpect(jsonPath("$._embedded.cases", hasSize(2)))
                .andExpect(jsonPath("$._embedded.cases[*].debtorName", containsInAnyOrder("Mario Rossi", "Luigi Verdi")))
                .andExpect(jsonPath("$.page.totalElements", is(2)));
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testCombinedFilters() throws Exception {
        // USER PREFERENCE: Verify test data exists before running the test
        long totalCases = debtCaseRepository.count();
        System.out.println("Total cases in DB before test: " + totalCases);

        // Verify specific cases exist with correct state and amount
        List<DebtCase> messaInMoraCases = debtCaseRepository.findAll().stream()
                .filter(c -> c.getCurrentState() == CaseState.MESSA_IN_MORA_DA_FARE)
                .filter(c -> c.getOwedAmount() >= 500.00) // USER PREFERENCE: Compare Double values directly for MongoDB
                .toList();

        System.out.println("Cases matching criteria: " + messaInMoraCases.size());
        messaInMoraCases.forEach(c -> System.out.println("- " + c.getDebtorName() + ": " + c.getOwedAmount()));

        mockMvc.perform(get("/cases")
                .param("state", "MESSA_IN_MORA_DA_FARE")
                .param("minAmount", "500")
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaTypes.HAL_JSON))
                .andExpect(jsonPath("$._embedded.cases", hasSize(2)))
                .andExpect(jsonPath("$._embedded.cases[*].debtorName", containsInAnyOrder("Mario Rossi", "Gianni Neri")))
                .andExpect(jsonPath("$.page.totalElements", is(2)));
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testFilterWithNoResults() throws Exception {
        mockMvc.perform(get("/cases")
                .param("debtorName", "NonExistent")
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaTypes.HAL_JSON))
                .andExpect(jsonPath("$._embedded").doesNotExist())
                .andExpect(jsonPath("$.page.totalElements", is(0)));
    }

    @Test
    void testGetCasesWithoutAuthentication() throws Exception {
        mockMvc.perform(get("/cases")
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testCreateDebtCase() throws Exception {
        // CUSTOM IMPLEMENTATION: Test for debt case creation via HTTP POST
        String requestBody = """
            {
                "debtorName": "Mario Rossi",
                "initialState": "MESSA_IN_MORA_DA_FARE",
                "lastStateDate": "2024-01-15T10:30:00",
                "amount": 1500.00
            }
            """;

        mockMvc.perform(post("/cases")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.debtorName").value("Mario Rossi"))
                .andExpect(jsonPath("$.state").value("MESSA_IN_MORA_DA_FARE"))
                .andExpect(jsonPath("$.owedAmount").value(1500.00))
                .andExpect(jsonPath("$.paid").value(false))
                .andExpect(jsonPath("$.hasInstallmentPlan").value(false))
                .andExpect(jsonPath("$.id").exists())
                .andExpect(jsonPath("$.lastStateDate").exists());
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testCreateDebtCase_WithValidationError() throws Exception {
        // CUSTOM IMPLEMENTATION: Test validation for debt case creation
        String requestBodyWithMissingFields = """
            {
                "debtorName": "",
                "amount": -100.00
            }
            """;

        mockMvc.perform(post("/cases")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBodyWithMissingFields))
                .andExpect(status().isBadRequest());
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testUpdateDebtCase() throws Exception {
        // CUSTOM IMPLEMENTATION: Test for debt case update via HTTP PUT
        // Prima creiamo un debt case
        var caseId = debtCaseService.createDebtCase(
            "Giovanni Bianchi",
            CaseState.MESSA_IN_MORA_DA_FARE,
            null,
            new BigDecimal("2000.00")
        ).getId();

        // Poi lo aggiorniamo via PUT
        String requestBody = """
            {
                "currentState": "DEPOSITO_RICORSO",
                "notes": "Passaggio a deposito ricorso tramite PUT"
            }
            """;

        mockMvc.perform(put("/cases/" + caseId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.id").value(caseId))
                .andExpect(jsonPath("$.debtorName").value("Giovanni Bianchi"))
                .andExpect(jsonPath("$.state").value("DEPOSITO_RICORSO"))
                .andExpect(jsonPath("$.owedAmount").value(2000.00))
                .andExpect(jsonPath("$.lastStateDate").exists());

        // Verifica che la modifica sia stata salvata nel database
        var updatedCase = debtCaseRepository.findById(caseId).orElseThrow();
        org.assertj.core.api.Assertions.assertThat(updatedCase.getCurrentState()).isEqualTo(CaseState.DEPOSITO_RICORSO);
        org.assertj.core.api.Assertions.assertThat(updatedCase.getNotes()).isEqualTo("Passaggio a deposito ricorso tramite PUT");
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testUpdateDebtCase_OnlyNotes() throws Exception {
        // CUSTOM IMPLEMENTATION: Test for updating only notes field
        var caseId = debtCaseService.createDebtCase(
            "Anna Verdi",
            CaseState.DECRETO_INGIUNTIVO_DA_NOTIFICARE,
            null,
            new BigDecimal("1500.00")
        ).getId();

        String requestBody = """
            {
                "notes": "Note aggiornate senza cambio stato"
            }
            """;

        mockMvc.perform(put("/cases/" + caseId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.state").value("DECRETO_INGIUNTIVO_DA_NOTIFICARE"))
                .andExpect(jsonPath("$.debtorName").value("Anna Verdi"));

        // Verifica che solo le note siano cambiate
        var updatedCase = debtCaseRepository.findById(caseId).orElseThrow();
        org.assertj.core.api.Assertions.assertThat(updatedCase.getCurrentState()).isEqualTo(CaseState.DECRETO_INGIUNTIVO_DA_NOTIFICARE);
        org.assertj.core.api.Assertions.assertThat(updatedCase.getNotes()).isEqualTo("Note aggiornate senza cambio stato");
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testUpdateDebtCase_NotFound() throws Exception {
        // CUSTOM IMPLEMENTATION: Test for updating non-existent debt case
        String requestBody = """
            {
                "currentState": "COMPLETATA",
                "notes": "Test case inesistente"
            }
            """;

        mockMvc.perform(put("/cases/99999")
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isInternalServerError()); // La RuntimeException diventa 500
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testUpdateDebtCase_PartialUpdate_OnlyState() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per verificare che i campi omessi restino invariati
        var caseId = debtCaseService.createDebtCase(
            "Test Partial Update",
            CaseState.MESSA_IN_MORA_DA_FARE,
            null,
            new BigDecimal("1000.00")
        ).getId();
        
        // Aggiungiamo delle note iniziali
        debtCaseService.updateDebtCase(caseId, null, null, null, null, null, null, null, "Note iniziali", null);

        // Ora aggiorniamo SOLO lo stato (senza fornire notes nel JSON)
        String requestBodyOnlyState = """
            {
                "currentState": "DEPOSITO_RICORSO"
            }
            """;

        mockMvc.perform(put("/cases/" + caseId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBodyOnlyState))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.state").value("DEPOSITO_RICORSO"));

        // Verifica che le note precedenti siano rimaste INVARIATE
        var updatedCase = debtCaseRepository.findById(caseId).orElseThrow();
        org.assertj.core.api.Assertions.assertThat(updatedCase.getCurrentState()).isEqualTo(CaseState.DEPOSITO_RICORSO);
        org.assertj.core.api.Assertions.assertThat(updatedCase.getNotes()).isEqualTo("Note iniziali"); // ✅ Non toccate!
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testUpdateDebtCase_PartialUpdate_OnlyNotes() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per verificare che lo stato omesso resti invariato
        var caseId = debtCaseService.createDebtCase(
            "Test Note Only",
            CaseState.PRECETTO,
            null,
            new BigDecimal("800.00")
        ).getId();

        // Aggiorniamo SOLO le note (senza fornire state nel JSON)
        String requestBodyOnlyNotes = """
            {
                "notes": "Solo note aggiornate"
            }
            """;

        mockMvc.perform(put("/cases/" + caseId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBodyOnlyNotes))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.state").value("PRECETTO")); // ✅ Stato invariato

        // Verifica che lo stato precedente sia rimasto INVARIATO
        var updatedCase = debtCaseRepository.findById(caseId).orElseThrow();
        org.assertj.core.api.Assertions.assertThat(updatedCase.getCurrentState()).isEqualTo(CaseState.PRECETTO); // ✅ Non toccato!
        org.assertj.core.api.Assertions.assertThat(updatedCase.getNotes()).isEqualTo("Solo note aggiornate");
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testUpdateDebtCase_ExplicitNull() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per verificare comportamento con null espliciti
        var caseId = debtCaseService.createDebtCase(
            "Test Explicit Null",
            CaseState.PIGNORAMENTO,
            null,
            new BigDecimal("1200.00")
        ).getId();

        // Aggiungiamo note iniziali
        debtCaseService.updateDebtCase(caseId, null, null, null, null, null, null, null, "Note da mantenere", null);

        // Inviamo null esplicito per le note
        String requestBodyWithExplicitNull = """
            {
                "currentState": "COMPLETATA",
                "notes": null
            }
            """;

        mockMvc.perform(put("/cases/" + caseId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBodyWithExplicitNull))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.state").value("COMPLETATA"));

        // Verifica che le note restino INVARIATE anche con null esplicito
        var updatedCase = debtCaseRepository.findById(caseId).orElseThrow();
        org.assertj.core.api.Assertions.assertThat(updatedCase.getCurrentState()).isEqualTo(CaseState.COMPLETATA);
        org.assertj.core.api.Assertions.assertThat(updatedCase.getNotes()).isEqualTo("Note da mantenere"); // ✅ Invariate
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testUpdateDebtCase_ExpandedFields() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per l'update espanso con tutti i campi modificabili
        var caseId = debtCaseService.createDebtCase(
            "Mario Verdi",
            CaseState.MESSA_IN_MORA_DA_FARE,
            null,
            new BigDecimal("1000.00")
        ).getId();

        // Update completo con tutti i campi modificabili
        String requestBody = """
            {
                "debtorName": "Mario Verdi AGGIORNATO",
                "owedAmount": 1250.50,
                "currentState": "PRECETTO",
                "nextDeadlineDate": "2025-12-31T23:59:59",
                "ongoingNegotiations": true,
                "hasInstallmentPlan": false,
                "paid": false,
                "notes": "Update completo di tutti i campi"
            }
            """;

        mockMvc.perform(put("/cases/" + caseId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.id").value(caseId))
                .andExpect(jsonPath("$.debtorName").value("Mario Verdi AGGIORNATO"))
                .andExpect(jsonPath("$.owedAmount").value(1250.50))
                .andExpect(jsonPath("$.state").value("PRECETTO"))
                .andExpect(jsonPath("$.paid").value(false))
                .andExpect(jsonPath("$.hasInstallmentPlan").value(false))
                .andExpect(jsonPath("$.lastStateDate").exists()); // currentStateDate dovrebbe essere aggiornata

        // Verifica persistenza nel database
        var updatedCase = debtCaseRepository.findById(caseId).orElseThrow();
        org.assertj.core.api.Assertions.assertThat(updatedCase.getDebtorName()).isEqualTo("Mario Verdi AGGIORNATO");
        org.assertj.core.api.Assertions.assertThat(updatedCase.getOwedAmount()).isEqualTo(1250.50); // USER PREFERENCE: Compare Double values directly for MongoDB
        org.assertj.core.api.Assertions.assertThat(updatedCase.getCurrentState()).isEqualTo(CaseState.PRECETTO);
        org.assertj.core.api.Assertions.assertThat(updatedCase.getOngoingNegotiations()).isTrue();
        org.assertj.core.api.Assertions.assertThat(updatedCase.getHasInstallmentPlan()).isFalse();
        org.assertj.core.api.Assertions.assertThat(updatedCase.getPaid()).isFalse();
        org.assertj.core.api.Assertions.assertThat(updatedCase.getNotes()).isEqualTo("Update completo di tutti i campi");
        org.assertj.core.api.Assertions.assertThat(updatedCase.getCurrentStateDate()).isNotNull();
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testUpdateDebtCase_ClearNotes() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per il flag clearNotes
        var caseId = debtCaseService.createDebtCase(
            "Test Clear Notes",
            CaseState.MESSA_IN_MORA_DA_FARE,
            null,
            new BigDecimal("500.00")
        ).getId();

        // Prima aggiungiamo delle note
        debtCaseService.updateDebtCase(caseId, null, null, null, null, null, null, null, "Note da cancellare", null);

        // Verifica che le note ci siano
        var caseWithNotes = debtCaseRepository.findById(caseId).orElseThrow();
        org.assertj.core.api.Assertions.assertThat(caseWithNotes.getNotes()).isEqualTo("Note da cancellare");

        // Ora cancelliamo le note usando clearNotes=true
        String requestBody = """
            {
                "clearNotes": true
            }
            """;

        mockMvc.perform(put("/cases/" + caseId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(caseId))
                .andExpect(jsonPath("$.debtorName").value("Test Clear Notes"));

        // Verifica che le note siano state settate a null
        var updatedCase = debtCaseRepository.findById(caseId).orElseThrow();
        org.assertj.core.api.Assertions.assertThat(updatedCase.getNotes()).isNull();
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testUpdateDebtCase_ClearNotesOverridesNotes() throws Exception {
        // CUSTOM IMPLEMENTATION: Test che clearNotes ha priorità su notes
        var caseId = debtCaseService.createDebtCase(
            "Test Priority",
            CaseState.PRECETTO,
            null,
            new BigDecimal("750.00")
        ).getId();

        // Prima aggiungiamo delle note
        debtCaseService.updateDebtCase(caseId, null, null, null, null, null, null, null, "Note esistenti", null);

        // Inviamo sia notes che clearNotes=true (clearNotes dovrebbe vincere)
        String requestBody = """
            {
                "notes": "Queste note dovrebbero essere ignorate",
                "clearNotes": true
            }
            """;

        mockMvc.perform(put("/cases/" + caseId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isOk());

        // Verifica che clearNotes abbia priorità e le note siano null
        var updatedCase = debtCaseRepository.findById(caseId).orElseThrow();
        org.assertj.core.api.Assertions.assertThat(updatedCase.getNotes()).isNull(); // clearNotes ha vinto
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testUpdateDebtCase_ClearNotesFalse() throws Exception {
        // CUSTOM IMPLEMENTATION: Test che clearNotes=false funzioni come omesso
        var caseId = debtCaseService.createDebtCase(
            "Test Clear False",
            CaseState.DEPOSITO_RICORSO,
            null,
            new BigDecimal("900.00")
        ).getId();

        // Prima aggiungiamo delle note
        debtCaseService.updateDebtCase(caseId, null, null, null, null, null, null, null, "Note da mantenere", null);

        // Inviamo clearNotes=false con nuove note
        String requestBody = """
            {
                "notes": "Note aggiornate",
                "clearNotes": false
            }
            """;

        mockMvc.perform(put("/cases/" + caseId)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isOk());

        // Verifica che le note siano state aggiornate normalmente
        var updatedCase = debtCaseRepository.findById(caseId).orElseThrow();
        org.assertj.core.api.Assertions.assertThat(updatedCase.getNotes()).isEqualTo("Note aggiornate");
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testDeleteDebtCase() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per cancellazione debt case via HTTP DELETE
        var caseId = debtCaseService.createDebtCase(
            "Case da cancellare",
            CaseState.MESSA_IN_MORA_DA_FARE,
            null,
            new BigDecimal("300.00")
        ).getId();

        // Verifica che il case esista prima della cancellazione
        org.assertj.core.api.Assertions.assertThat(debtCaseRepository.existsById(caseId)).isTrue();

        // Cancella via DELETE
        mockMvc.perform(delete("/cases/" + caseId))
                .andExpect(status().isNoContent()); // 204 No Content

        // Verifica che il case sia stato cancellato dal database
        org.assertj.core.api.Assertions.assertThat(debtCaseRepository.existsById(caseId)).isFalse();
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testDeleteDebtCase_NotFound() throws Exception {
        // CUSTOM IMPLEMENTATION: Test per cancellazione di debt case inesistente
        mockMvc.perform(delete("/cases/99999"))
                .andExpect(status().isInternalServerError()); // 500 per RuntimeException
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testDeleteDebtCase_WithRelatedData() throws Exception {
        // CUSTOM IMPLEMENTATION: Test cancellazione con dati correlati (payments/installments)
        var caseId = debtCaseService.createDebtCase(
            "Case con dati correlati",
            CaseState.PRECETTO,
            null,
            new BigDecimal("1500.00")
        ).getId();

        // Aggiungi un pagamento correlato
        String paymentRequest = """
            {
                "amount": 100.00,
                "paymentDate": "2024-01-15T10:30:00"
            }
            """;
        
        mockMvc.perform(post("/cases/" + caseId + "/payments")
                .contentType(MediaType.APPLICATION_JSON)
                .content(paymentRequest))
                .andExpect(status().isOk());

        // Verifica che il case e payment esistano
        org.assertj.core.api.Assertions.assertThat(debtCaseRepository.existsById(caseId)).isTrue();

        // Cancella il debt case (dovrebbe cancellare anche i dati correlati per cascade)
        mockMvc.perform(delete("/cases/" + caseId))
                .andExpect(status().isNoContent());

        // Verifica che il case sia stato cancellato
        org.assertj.core.api.Assertions.assertThat(debtCaseRepository.existsById(caseId)).isFalse();
        
        // Note: I payments dovrebbero essere cancellati automaticamente per cascade
    }

    @Test
    void testDeleteDebtCase_WithoutAuthentication() throws Exception {
        // CUSTOM IMPLEMENTATION: Test sicurezza per DELETE senza autenticazione
        mockMvc.perform(delete("/cases/1"))
                .andExpect(status().isUnauthorized()); // 401 Unauthorized
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testFilterByAmountRange_InvalidRange() throws Exception {
        mockMvc.perform(get("/cases")
                .param("minAmount", "3000")
                .param("maxAmount", "1000")
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("L'importo minimo non può essere maggiore dell'importo massimo"))
                .andExpect(jsonPath("$.error").value("IllegalArgumentException"));
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testFilterByAmountRange_MinEqualsMax() throws Exception {
        mockMvc.perform(get("/cases")
                .param("minAmount", "1000.00")
                .param("maxAmount", "1000.00")
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$._embedded.cases", hasSize(1)))
                .andExpect(jsonPath("$._embedded.cases[0].debtorName").value("Mario Rossi"))
                .andExpect(jsonPath("$.page.totalElements").value(1));
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testFilterByNotes_SubstringCaseInsensitive() throws Exception {
        // Add notes to two cases
        DebtCase mario = debtCaseRepository.findAll().stream().filter(c -> c.getDebtorName().equals("Mario Rossi")).findFirst().orElseThrow();
        mario.setNotes("Urgente - verifica documenti");
        debtCaseRepository.save(mario);
        DebtCase gianni = debtCaseRepository.findAll().stream().filter(c -> c.getDebtorName().equals("Gianni Neri")).findFirst().orElseThrow();
        gianni.setNotes("Non urgente - rateo futuro");
        debtCaseRepository.save(gianni);

        // Search substring 'URGENTE' should match both (case-insensitive, substring)
        mockMvc.perform(get("/cases")
                .param("notes", "urgente")
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$._embedded.cases", hasSize(2)))
                .andExpect(jsonPath("$._embedded.cases[*].debtorName", containsInAnyOrder("Mario Rossi", "Gianni Neri")));

        // Search substring 'verifica' only Mario
        mockMvc.perform(get("/cases")
                .param("notes", "verifica")
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$._embedded.cases", hasSize(1)))
                .andExpect(jsonPath("$._embedded.cases[0].debtorName").value("Mario Rossi"));
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testFilterByCurrentStateDateRange() throws Exception {
        // Prepare deterministic dates
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime older = now.minusDays(10).withNano(0);
        LocalDateTime newer = now.minusDays(2).withNano(0);

        // Assign to two cases
        DebtCase mario = debtCaseRepository.findAll().stream().filter(c -> c.getDebtorName().equals("Mario Rossi")).findFirst().orElseThrow();
        mario.setCurrentStateDate(older);
        debtCaseRepository.save(mario);
        DebtCase gianni = debtCaseRepository.findAll().stream().filter(c -> c.getDebtorName().equals("Gianni Neri")).findFirst().orElseThrow();
        gianni.setCurrentStateDate(newer);
        debtCaseRepository.save(gianni);

        // Narrow range to only capture 'newer' timestamp (±1 second)
        LocalDateTime from = newer.minusSeconds(1);
        LocalDateTime to = newer.plusSeconds(1);
        mockMvc.perform(get("/cases")
                .param("currentStateFrom", from.toLocalDate().toString())
                .param("currentStateTo", to.toLocalDate().toString())
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$._embedded.cases", hasSize(1)))
                .andExpect(jsonPath("$._embedded.cases[0].debtorName").value("Gianni Neri"));
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testFilterByCurrentStateDateRange_InclusiveBoundary() throws Exception {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime boundary = now.minusDays(5).withNano(0);
        DebtCase luigi = debtCaseRepository.findAll().stream().filter(c -> c.getDebtorName().equals("Luigi Verdi")).findFirst().orElseThrow();
        luigi.setCurrentStateDate(boundary);
        debtCaseRepository.save(luigi);

        mockMvc.perform(get("/cases")
                .param("currentStateFrom", boundary.toLocalDate().toString())
                .param("currentStateTo", now.plusDays(1).toLocalDate().toString())
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$._embedded.cases[*].debtorName", hasItem("Luigi Verdi")));
    }

    @Test
    @WithMockUser(username = "testuser", roles = "USER")
    void testCombinedNotesStateAndDateFilters() throws Exception {
        LocalDateTime tagDate = LocalDateTime.now().minusDays(7).withNano(0);
        DebtCase anna = debtCaseRepository.findAll().stream().filter(c -> c.getDebtorName().equals("Anna Bianchi")).findFirst().orElseThrow();
        anna.setNotes("Pratica sospesa per integrazione documenti");
        anna.setCurrentStateDate(tagDate);
        debtCaseRepository.save(anna);

        mockMvc.perform(get("/cases")
                .param("notes", "integrazione")
                .param("state", anna.getCurrentState().name())
                .param("currentStateFrom", tagDate.minusHours(1).toLocalDate().toString())
                .param("currentStateTo", tagDate.plusHours(1).toLocalDate().toString())
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$._embedded.cases", hasSize(1)))
                .andExpect(jsonPath("$._embedded.cases[0].debtorName").value("Anna Bianchi"));
    }
}
