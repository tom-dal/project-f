package com.debtcollection.service;

import com.debtcollection.model.CaseState;
import com.debtcollection.model.StateTransitionConfig;
import com.debtcollection.repository.StateTransitionConfigRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
public class StateTransitionService {

    private static final Logger log = LoggerFactory.getLogger(StateTransitionService.class);
    private final Map<CaseState, StateTransitionConfig> cache = new ConcurrentHashMap<>();

    private final StateTransitionConfigRepository stateTransitionConfigRepository;

    public void refreshCache() {
        cache.clear();
        stateTransitionConfigRepository.findAll().forEach(config -> {
            cache.put(config.getFromState(), config);
        });
        // DEBUG: log all state transitions loaded
        log.info("Loaded state transitions:");
        cache.forEach((state, config) -> log.info("from_state={} to_state={} days={}", state, config.getToState(), config.getDaysToTransition()));
    }

    // DEBUG: log state transitions at bean initialization
    @PostConstruct
    public void logTransitionsAtStartup() {
        log.info("[DEBUG] StateTransitionService @PostConstruct - Checking state_transition_config content");
        stateTransitionConfigRepository.findAll().forEach(config ->
            log.info("[DEBUG] DB: from_state={} to_state={} days={}", config.getFromState(), config.getToState(), config.getDaysToTransition()));
    }

    public LocalDate calculateNextDeadline(CaseState fromState, LocalDateTime lastStateDate) {
        if(fromState == CaseState.COMPLETATA) {
            return LocalDate.MAX;
        }
        StateTransitionConfig config = cache.computeIfAbsent(fromState, stateTransitionConfigRepository::findByFromState);
        if (config == null) {
            throw new IllegalArgumentException("No transition configuration found for state: " + fromState);
        }
        return lastStateDate.toLocalDate().plusDays(config.getDaysToTransition());
    }

}
