package com.debtcollection.controller;

import com.debtcollection.dto.InstallmentPlanRequest;
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
import java.time.format.DateTimeFormatter;

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultHandlers.print;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

// CUSTOM IMPLEMENTATION: Integration tests to cover missing filter branches for GET /cases
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestPropertySource(locations = "classpath:application-test.properties")
class DebtCaseControllerFiltersIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DebtCaseService debtCaseService;

    @Autowired
    private DebtCaseRepository debtCaseRepository; // used only where service does not expose a setter (active flag)

    @Autowired
    private StateTransitionConfigRepository stateTransitionConfigRepository; // Needed to seed transitions

    private String alphaId; // MESSA_IN_MORA_DA_FARE
    private String betaId;  // DEPOSITO_RICORSO
    private String gammaId; // PRECETTO
    private String deltaId; // COMPLETATA (inactive)

    private LocalDateTime betaNextDeadline;
    private LocalDateTime gammaNextDeadline;

    @BeforeEach
    void setup() {
        debtCaseRepository.deleteAll();
        stateTransitionConfigRepository.deleteAll();
        createStateTransitionConfigs(); // Seed required transitions before using service

        // Create base cases via service (USER PREFERENCE: use service where possible)
        alphaId = debtCaseService.createDebtCase("Filter Alpha", CaseState.MESSA_IN_MORA_DA_FARE, null, new BigDecimal("1000.00")).getId();
        betaId  = debtCaseService.createDebtCase("Filter Beta",  CaseState.DEPOSITO_RICORSO, null, new BigDecimal("2000.00")).getId();
        gammaId = debtCaseService.createDebtCase("Filter Gamma", CaseState.PRECETTO, null, new BigDecimal("3000.00")).getId();
        deltaId = debtCaseService.createDebtCase("Filter Delta", CaseState.COMPLETATA, null, new BigDecimal("4000.00")).getId();

        // Definisce la deadline per Beta e crea prima il piano rateale coerente
        betaNextDeadline = LocalDateTime.now().plusDays(5);
        InstallmentPlanRequest planRequest = new InstallmentPlanRequest();
        planRequest.setNumberOfInstallments(2);
        planRequest.setFirstInstallmentDueDate(betaNextDeadline);
        planRequest.setInstallmentAmount(new BigDecimal("1000.00"));
        planRequest.setFrequencyDays(30);
        debtCaseService.createInstallmentPlan(betaId, planRequest);

        // Ora aggiorna Beta con ongoingNegotiations e notes (hasInstallmentPlan resta invariato)
        debtCaseService.updateDebtCase(betaId, null, null, null, null, true, null, false, "Important KEYWORD note", null);

        // Update Gamma: set nextDeadlineDate further in future
        gammaNextDeadline = LocalDateTime.now().plusDays(10);
        debtCaseService.updateDebtCase(gammaId, null, null, null, gammaNextDeadline, false, null, false, null, null);

        // Mark Delta inactive directly (no service method available)
        DebtCase delta = debtCaseRepository.findById(deltaId).orElseThrow();
        delta.setActive(false); // USER PREFERENCE: default active true overridden for inactive filter test
        debtCaseRepository.save(delta);
    }

    private void createStateTransitionConfigs() {
        // USER PREFERENCE: replicate transition config seeding used in other integration tests
        addTransition(CaseState.MESSA_IN_MORA_DA_FARE, CaseState.DECRETO_INGIUNTIVO_DA_NOTIFICARE, 30);
        addTransition(CaseState.DECRETO_INGIUNTIVO_DA_NOTIFICARE, CaseState.DECRETO_INGIUNTIVO_NOTIFICATO, 10);
        addTransition(CaseState.DECRETO_INGIUNTIVO_NOTIFICATO, CaseState.PRECETTO, 40);
        addTransition(CaseState.PRECETTO, CaseState.PIGNORAMENTO, 10);
        addTransition(CaseState.PIGNORAMENTO, CaseState.DEPOSITO_RICORSO, 30);
        addTransition(CaseState.DEPOSITO_RICORSO, CaseState.COMPLETATA, 90);
        // Include a self-loop for states we instantiate directly but may not transition from
        // (Optional safety – can be omitted if not required by validator logic)
    }

    private void addTransition(CaseState from, CaseState to, int days) {
        StateTransitionConfig cfg = new StateTransitionConfig();
        cfg.setFromState(from);
        cfg.setToState(to);
        cfg.setDaysToTransition(days);
        stateTransitionConfigRepository.save(cfg);
    }

    private static DateTimeFormatter fmt() {
        return DateTimeFormatter.ISO_LOCAL_DATE_TIME;
    }

    @Test
    @WithMockUser(username = "user", roles = "USER")
    void filterByStatesList() throws Exception {
        mockMvc.perform(get("/cases")
                .param("states", "MESSA_IN_MORA_DA_FARE")
                .param("states", "PRECETTO")
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaTypes.HAL_JSON))
                .andExpect(jsonPath("$._embedded.cases[*].debtorName", containsInAnyOrder("Filter Alpha", "Filter Gamma")))
                .andExpect(jsonPath("$.page.totalElements", is(2)));
    }

    @Test
    @WithMockUser(username = "user", roles = "USER")
    void filterOnlyMinAmount() throws Exception {
        mockMvc.perform(get("/cases")
                .param("minAmount", "2500")
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$._embedded.cases", hasSize(1)))
                .andExpect(jsonPath("$._embedded.cases[0].debtorName", is("Filter Gamma")))
                .andExpect(jsonPath("$.page.totalElements", is(1)));
    }

    @Test
    @WithMockUser(username = "user", roles = "USER")
    void filterOnlyMaxAmount() throws Exception {
        mockMvc.perform(get("/cases")
                .param("maxAmount", "1500")
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$._embedded.cases", hasSize(1)))
                .andExpect(jsonPath("$._embedded.cases[0].debtorName", is("Filter Alpha")))
                .andExpect(jsonPath("$.page.totalElements", is(1)));
    }

    @Test
    @WithMockUser(username = "user", roles = "USER")
    void filterHasInstallmentPlanTrue() throws Exception {
        mockMvc.perform(get("/cases")
                .param("hasInstallmentPlan", "true")
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$._embedded.cases", hasSize(1)))
                .andExpect(jsonPath("$._embedded.cases[0].debtorName", is("Filter Beta")))
                .andExpect(jsonPath("$.page.totalElements", is(1)));
    }

    @Test
    @WithMockUser(username = "user", roles = "USER")
    void filterPaidFalseBranch() throws Exception {
        mockMvc.perform(get("/cases")
                .param("paid", "false")
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isOk())
                // active=true default, so 3 active unpaid cases
                .andExpect(jsonPath("$._embedded.cases", hasSize(3)))
                .andExpect(jsonPath("$._embedded.cases[*].debtorName", containsInAnyOrder("Filter Alpha", "Filter Beta", "Filter Gamma")))
                .andExpect(jsonPath("$.page.totalElements", is(3)));
    }

    @Test
    @WithMockUser(username = "user", roles = "USER")
    void filterOngoingNegotiationsTrue() throws Exception {
        mockMvc.perform(get("/cases")
                .param("ongoingNegotiations", "true")
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$._embedded.cases", hasSize(1)))
                .andExpect(jsonPath("$._embedded.cases[0].debtorName", is("Filter Beta")))
                .andExpect(jsonPath("$.page.totalElements", is(1)));
    }

    @Test
    @WithMockUser(username = "user", roles = "USER")
    void filterActiveFalse() throws Exception {
        mockMvc.perform(get("/cases")
                .param("active", "false")
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$._embedded.cases", hasSize(1)))
                .andExpect(jsonPath("$._embedded.cases[0].debtorName", is("Filter Delta")))
                .andExpect(jsonPath("$.page.totalElements", is(1)));
    }

    @Test
    @WithMockUser(username = "user", roles = "USER")
    void filterByNotesSubstringCaseInsensitive() throws Exception {
        mockMvc.perform(get("/cases")
                .param("notes", "keyword")
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$._embedded.cases", hasSize(1)))
                .andExpect(jsonPath("$._embedded.cases[0].debtorName", is("Filter Beta")))
                .andExpect(jsonPath("$.page.totalElements", is(1)));
    }

    @Test
    @WithMockUser(username = "user", roles = "USER")
    void filterNextDeadlineRange() throws Exception {
        String from = betaNextDeadline.minusDays(1).withNano(0).format(fmt());
        String to   = betaNextDeadline.plusDays(1).withNano(0).format(fmt());
        mockMvc.perform(get("/cases")
                .param("nextDeadlineFrom", from)
                .param("nextDeadlineTo", to)
                .contentType(MediaType.APPLICATION_JSON))
                .andDo(print())
                .andExpect(status().isOk())
                .andExpect(jsonPath("$._embedded.cases", hasSize(1)))
                .andExpect(jsonPath("$._embedded.cases[0].debtorName", is("Filter Beta")))
                .andExpect(jsonPath("$.page.totalElements", is(1)));
    }
}
