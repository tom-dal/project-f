package com.debtcollection.model;

import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

class DebtCaseTest {
    
    @Test
    void getCurrentState_ShouldReturnNull_WhenNotSet() {
        DebtCase debtCase = new DebtCase();
        assertNull(debtCase.getCurrentState());
    }

    @Test
    void getCurrentState_ShouldReturnDirectState() {
        DebtCase debtCase = new DebtCase();
        debtCase.setCurrentState(CaseState.MESSA_IN_MORA_DA_FARE);
        debtCase.setCurrentStateDate(LocalDateTime.now());
        assertEquals(CaseState.MESSA_IN_MORA_DA_FARE, debtCase.getCurrentState());
    }
}
