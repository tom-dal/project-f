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
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestPropertySource(locations = "classpath:application-test.properties")
public class DebtCasePaginationIntegrationTest {

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

        // USER PREFERENCE: Create test data directly via repository to bypass state machine validation in tests
        for (int i = 1; i <= 25; i++) {
            DebtCase debtCase = new DebtCase();
            debtCase.setDebtorName("Debtor " + i);
            debtCase.setOwedAmount((double)(1000 + i)); // USER PREFERENCE: Convert to Double for MongoDB
            debtCase.setCurrentState(CaseState.MESSA_IN_MORA_DA_FARE);
            debtCase.setCurrentStateDate(LocalDateTime.now());
            debtCase.setHasInstallmentPlan(false);
            debtCase.setPaid(false);
            debtCase.setOngoingNegotiations(false);
            debtCaseRepository.save(debtCase);
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
    @WithMockUser
    void testDefaultPagination() throws Exception {
        mockMvc.perform(get("/cases"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaTypes.HAL_JSON))
                .andExpect(jsonPath("$._embedded.cases").exists())
                .andExpect(jsonPath("$._embedded.cases").isArray())
                .andExpect(jsonPath("$._embedded.cases.length()").value(20)) // Default page size
                .andExpect(jsonPath("$.page.size").value(20))
                .andExpect(jsonPath("$.page.totalElements").value(25))
                .andExpect(jsonPath("$.page.totalPages").value(2))
                .andExpect(jsonPath("$.page.number").value(0))
                .andExpect(jsonPath("$._links.self").exists())
                .andExpect(jsonPath("$._links.next").exists());
    }

    @Test
    @WithMockUser
    void testCustomPageSize() throws Exception {
        mockMvc.perform(get("/cases?size=10"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaTypes.HAL_JSON))
                .andExpect(jsonPath("$._embedded.cases.length()").value(10))
                .andExpect(jsonPath("$.page.size").value(10))
                .andExpect(jsonPath("$.page.totalElements").value(25))
                .andExpect(jsonPath("$.page.totalPages").value(3))
                .andExpect(jsonPath("$.page.number").value(0));
    }

    @Test
    @WithMockUser
    void testSecondPage() throws Exception {
        mockMvc.perform(get("/cases?page=1&size=10"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaTypes.HAL_JSON))
                .andExpect(jsonPath("$._embedded.cases.length()").value(10))
                .andExpect(jsonPath("$.page.size").value(10))
                .andExpect(jsonPath("$.page.totalElements").value(25))
                .andExpect(jsonPath("$.page.totalPages").value(3))
                .andExpect(jsonPath("$.page.number").value(1))
                .andExpect(jsonPath("$._links.self").exists())
                .andExpect(jsonPath("$._links.prev").exists())
                .andExpect(jsonPath("$._links.next").exists());
    }

    @Test
    @WithMockUser
    void testLastPage() throws Exception {
        mockMvc.perform(get("/cases?page=2&size=10"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaTypes.HAL_JSON))
                .andExpect(jsonPath("$._embedded.cases.length()").value(5)) // Last page has 5 items
                .andExpect(jsonPath("$.page.size").value(10))
                .andExpect(jsonPath("$.page.totalElements").value(25))
                .andExpect(jsonPath("$.page.totalPages").value(3))
                .andExpect(jsonPath("$.page.number").value(2))
                .andExpect(jsonPath("$._links.self").exists())
                .andExpect(jsonPath("$._links.prev").exists())
                .andExpect(jsonPath("$._links.next").doesNotExist()); // No next page
    }

    @Test
    @WithMockUser
    void testSortByInitialOwedAmount() throws Exception {
        mockMvc.perform(get("/cases?sort=owedAmount,desc&size=5"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaTypes.HAL_JSON))
                .andExpect(jsonPath("$._embedded.cases[0].owedAmount").value(1025.0)) // Highest amount
                .andExpect(jsonPath("$._embedded.cases[4].owedAmount").value(1021.0)); // 5th highest
    }

    @Test
    @WithMockUser
    void testSortByDebtorName() throws Exception {
        mockMvc.perform(get("/cases?sort=debtorName,asc&size=5"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaTypes.HAL_JSON))
                .andExpect(jsonPath("$._embedded.cases[0].debtorName").value("Debtor 1"))
                .andExpect(jsonPath("$._embedded.cases[1].debtorName").value("Debtor 10"));
    }

    @Test
    @WithMockUser
    void testInvalidPageNumber() throws Exception {
        mockMvc.perform(get("/cases?page=-1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page.number").value(0)); // Should default to 0
    }

    @Test
    @WithMockUser
    void testInvalidPageSize() throws Exception {
        mockMvc.perform(get("/cases?size=0"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page.size").value(20)); // Should default to 20
    }

    @Test
    @WithMockUser
    void testExcessivePageSize() throws Exception {
        mockMvc.perform(get("/cases?size=1000"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page.size").value(50)); // Should be capped at 100
    }

    @Test
    @WithMockUser
    void testEmptyResults() throws Exception {
        // Clear all data
        debtCaseRepository.deleteAll();

        mockMvc.perform(get("/cases"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaTypes.HAL_JSON))
                .andExpect(jsonPath("$._embedded").doesNotExist()) // No embedded when empty
                .andExpect(jsonPath("$.page.totalElements").value(0))
                .andExpect(jsonPath("$.page.totalPages").value(0))
                .andExpect(jsonPath("$._links.self").exists());
    }

    @Test
    @WithMockUser
    void testHATEOASLinksStructure() throws Exception {
        mockMvc.perform(get("/cases?page=1&size=10"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaTypes.HAL_JSON))
                .andExpect(jsonPath("$._links").exists())
                .andExpect(jsonPath("$._links.self").exists())
                .andExpect(jsonPath("$._links.self.href").isString())
                .andExpect(jsonPath("$._links.first").exists())
                .andExpect(jsonPath("$._links.prev").exists())
                .andExpect(jsonPath("$._links.next").exists())
                .andExpect(jsonPath("$._links.last").exists());
    }
}
