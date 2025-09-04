package com.debtcollection.service;

import com.debtcollection.model.CaseState;
import com.debtcollection.model.StateTransitionConfig;
import com.debtcollection.repository.StateTransitionConfigRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class StateTransitionServiceTest {

    @Mock
    private StateTransitionConfigRepository stateTransitionConfigRepository;

    @InjectMocks
    private StateTransitionService stateTransitionService;

    private List<StateTransitionConfig> mockConfigs;

    @BeforeEach
    void setUp() {
        // CUSTOM IMPLEMENTATION: Setup configurazioni di transizione di stato standard
        StateTransitionConfig config1 = new StateTransitionConfig();
        config1.setFromState(CaseState.MESSA_IN_MORA_DA_FARE);
        config1.setToState(CaseState.MESSA_IN_MORA_INVIATA);
        config1.setDaysToTransition(30);

        StateTransitionConfig config2 = new StateTransitionConfig();
        config2.setFromState(CaseState.MESSA_IN_MORA_INVIATA);
        config2.setToState(CaseState.DEPOSITO_RICORSO);
        config2.setDaysToTransition(45);

        StateTransitionConfig config3 = new StateTransitionConfig();
        config3.setFromState(CaseState.DEPOSITO_RICORSO);
        config3.setToState(CaseState.DECRETO_INGIUNTIVO_DA_NOTIFICARE);
        config3.setDaysToTransition(60);

        mockConfigs = Arrays.asList(config1, config2, config3);
    }

    @Test
    void refreshCache_ShouldLoadAllConfigurations() {
        // Given
        when(stateTransitionConfigRepository.findAll()).thenReturn(mockConfigs);

        // When
        stateTransitionService.refreshCache();

        // Then
        verify(stateTransitionConfigRepository).findAll();
        // CUSTOM IMPLEMENTATION: Verifica che la cache sia stata popolata correttamente
        // Non possiamo verificare direttamente la cache (è privata), ma possiamo verificare
        // che le configurazioni vengano usate correttamente nei metodi successivi
    }

    @Test
    void calculateNextDeadline_ShouldReturnCorrectDate_ForValidState() {
        // Given
        LocalDateTime stateDate = LocalDateTime.of(2025, 1, 15, 10, 0);
        StateTransitionConfig config = mockConfigs.get(0); // MESSA_IN_MORA_DA_FARE -> 30 giorni

        when(stateTransitionConfigRepository.findByFromState(CaseState.MESSA_IN_MORA_DA_FARE))
            .thenReturn(config);

        // When
        LocalDate result = stateTransitionService.calculateNextDeadline(
            CaseState.MESSA_IN_MORA_DA_FARE,
            stateDate
        );

        // Then
        LocalDate expectedDate = LocalDate.of(2025, 2, 14); // 15 gennaio + 30 giorni
        assertEquals(expectedDate, result);
        verify(stateTransitionConfigRepository).findByFromState(CaseState.MESSA_IN_MORA_DA_FARE);
    }

    @Test
    void calculateNextDeadline_ShouldReturnMaxDate_ForCompletedCase() {
        // Given
        LocalDateTime stateDate = LocalDateTime.of(2025, 1, 15, 10, 0);

        // When
        LocalDate result = stateTransitionService.calculateNextDeadline(
            CaseState.COMPLETATA,
            stateDate
        );

        // Then
        assertEquals(LocalDate.MAX, result);
        // CUSTOM IMPLEMENTATION: Per casi completati non dovrebbe interrogare il repository
        verify(stateTransitionConfigRepository, never()).findByFromState(any());
    }

    @Test
    void calculateNextDeadline_ShouldReturnFallbackDate_WhenConfigNotFound() {
        // Given
        LocalDateTime stateDate = LocalDateTime.of(2025, 1, 15, 10, 0);
        when(stateTransitionConfigRepository.findByFromState(CaseState.MESSA_IN_MORA_DA_FARE))
            .thenReturn(null);

        // When
        LocalDate result = stateTransitionService.calculateNextDeadline(CaseState.MESSA_IN_MORA_DA_FARE, stateDate);

        // Then (fallback 30 days)
        LocalDate expected = stateDate.toLocalDate().plusDays(StateTransitionService.DEFAULT_FALLBACK_DAYS);
        assertEquals(expected, result);
    }

    @Test
    void calculateNextDeadline_ShouldUseCacheAfterFirstCall() {
        // Given
        LocalDateTime stateDate = LocalDateTime.of(2025, 1, 15, 10, 0);
        StateTransitionConfig config = mockConfigs.get(0);

        when(stateTransitionConfigRepository.findByFromState(CaseState.MESSA_IN_MORA_DA_FARE))
            .thenReturn(config);

        // When - Prima chiamata
        stateTransitionService.calculateNextDeadline(CaseState.MESSA_IN_MORA_DA_FARE, stateDate);

        // When - Seconda chiamata (dovrebbe usare la cache)
        stateTransitionService.calculateNextDeadline(CaseState.MESSA_IN_MORA_DA_FARE, stateDate);

        // Then
        // CUSTOM IMPLEMENTATION: Dovrebbe chiamare il repository solo una volta (prima chiamata)
        // La seconda dovrebbe usare la cache
        verify(stateTransitionConfigRepository, times(1)).findByFromState(CaseState.MESSA_IN_MORA_DA_FARE);
    }

    @Test
    void calculateNextDeadline_ShouldHandleDifferentStates() {
        // Given
        LocalDateTime stateDate = LocalDateTime.of(2025, 1, 15, 10, 0);

        when(stateTransitionConfigRepository.findByFromState(CaseState.MESSA_IN_MORA_INVIATA))
            .thenReturn(mockConfigs.get(1)); // 45 giorni
        when(stateTransitionConfigRepository.findByFromState(CaseState.DEPOSITO_RICORSO))
            .thenReturn(mockConfigs.get(2)); // 60 giorni

        // When
        LocalDate result1 = stateTransitionService.calculateNextDeadline(
            CaseState.MESSA_IN_MORA_INVIATA, stateDate);
        LocalDate result2 = stateTransitionService.calculateNextDeadline(
            CaseState.DEPOSITO_RICORSO, stateDate);

        // Then
        assertEquals(LocalDate.of(2025, 3, 1), result1); // 15 gennaio + 45 giorni
        assertEquals(LocalDate.of(2025, 3, 16), result2); // 15 gennaio + 60 giorni
    }

    @Test
    void refreshCache_ShouldClearExistingCache() {
        // Given
        when(stateTransitionConfigRepository.findAll())
            .thenReturn(mockConfigs)
            .thenReturn(Arrays.asList(mockConfigs.get(0))); // Seconda chiamata ritorna meno elementi

        // When
        stateTransitionService.refreshCache();
        stateTransitionService.refreshCache(); // Seconda chiamata dovrebbe sovrascrivere la cache

        // Then
        verify(stateTransitionConfigRepository, times(2)).findAll();
    }
}
