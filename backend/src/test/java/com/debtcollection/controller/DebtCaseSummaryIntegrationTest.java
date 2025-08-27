package com.debtcollection.controller;

import com.debtcollection.model.CaseState;
import com.debtcollection.model.DebtCase;
import com.debtcollection.repository.DebtCaseRepository;
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

import java.time.LocalDate;
import java.time.LocalDateTime;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultHandlers.print;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.hamcrest.Matchers.*;

/**
 * Integration test per endpoint /cases/summary
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestPropertySource(locations = "classpath:application-test.properties")
public class DebtCaseSummaryIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DebtCaseRepository debtCaseRepository;

    @BeforeEach
    void setup() {
        debtCaseRepository.deleteAll();
        LocalDate today = LocalDate.now();

        DebtCase overdue = new DebtCase();
        overdue.setDebtorName("Deadline -1");
        overdue.setCurrentState(CaseState.MESSA_IN_MORA_INVIATA);
        overdue.setCurrentStateDate(LocalDateTime.now());
        overdue.setNextDeadlineDate(today.minusDays(1).atStartOfDay());
        debtCaseRepository.save(overdue);

        DebtCase c1 = new DebtCase();
        c1.setDebtorName("Deadline Oggi");
        c1.setCurrentState(CaseState.MESSA_IN_MORA_DA_FARE);
        c1.setCurrentStateDate(LocalDateTime.now());
        c1.setNextDeadlineDate(today.atStartOfDay());
        debtCaseRepository.save(c1);

        DebtCase c2 = new DebtCase();
        c2.setDebtorName("Deadline +3");
        c2.setCurrentState(CaseState.DEPOSITO_RICORSO);
        c2.setCurrentStateDate(LocalDateTime.now());
        c2.setNextDeadlineDate(today.plusDays(3).atStartOfDay());
        debtCaseRepository.save(c2);

        DebtCase c3 = new DebtCase();
        c3.setDebtorName("Deadline +10");
        c3.setCurrentState(CaseState.PRECETTO);
        c3.setCurrentStateDate(LocalDateTime.now());
        c3.setNextDeadlineDate(today.plusDays(10).atStartOfDay());
        debtCaseRepository.save(c3);

        DebtCase c4 = new DebtCase();
        c4.setDebtorName("Completata");
        c4.setCurrentState(CaseState.COMPLETATA);
        c4.setCurrentStateDate(LocalDateTime.now());
        c4.setNextDeadlineDate(today.atStartOfDay());
        debtCaseRepository.save(c4);
    }

    @Test
    @WithMockUser(username = "summaryUser", roles = "USER")
    void testSummaryEndpoint() throws Exception {
        mockMvc.perform(get("/cases/summary").contentType(MediaType.APPLICATION_JSON))
            .andDo(print())
            .andExpect(status().isOk())
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
            .andExpect(jsonPath("$.totalActiveCases", is(4))) // esclude COMPLETATA
            .andExpect(jsonPath("$.overdue", is(1)))
            .andExpect(jsonPath("$.dueToday", is(1)))
            .andExpect(jsonPath("$.dueNext7Days", is(2))) // include oggi +3, esclude -1 e +10
            .andExpect(jsonPath("$.states.MESSA_IN_MORA_INVIATA", is(1)))
            .andExpect(jsonPath("$.states.MESSA_IN_MORA_DA_FARE", is(1)))
            .andExpect(jsonPath("$.states.DEPOSITO_RICORSO", is(1)))
            .andExpect(jsonPath("$.states.PRECETTO", is(1)))
            .andExpect(jsonPath("$.states.COMPLETATA").doesNotExist());
    }
}
