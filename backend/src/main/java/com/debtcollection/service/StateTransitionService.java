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
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
public class StateTransitionService {

    private static final Logger log = LoggerFactory.getLogger(StateTransitionService.class);
    private final Map<CaseState, StateTransitionConfig> cache = new ConcurrentHashMap<>();

    private final StateTransitionConfigRepository stateTransitionConfigRepository;

    public static final int DEFAULT_FALLBACK_DAYS = 10;

    public void refreshCache() {
        cache.clear();
        stateTransitionConfigRepository.findAll().forEach(config -> {
            cache.put(config.getFromState(), config);
        });
        // DEBUG: log all state transitions loaded
        log.info("Loaded state transitions:");
        cache.forEach((state, config) -> log.info("from_state={} to_state={} days={}", state, config.getToState(), config.getDaysToTransition()));
    }

    @PostConstruct
    public void logTransitionsAtStartup() {
        log.info("[DEBUG] StateTransitionService @PostConstruct - Checking state_transition_config content");
        stateTransitionConfigRepository.findAll().forEach(config ->
            log.info("[DEBUG] DB: from_state={} to_state={} days={}", config.getFromState(), config.getToState(), config.getDaysToTransition()));
        try {
            refreshCache();
            log.info("[DEBUG] Cache preloaded with {} transition configs", cache.size());
        } catch (Exception e) {
            log.warn("[WARN] Failed to preload state transition cache: {}", e.getMessage());
        }
    }

    public LocalDate calculateNextDeadline(CaseState fromState, LocalDateTime lastStateDate) {
        if(fromState == CaseState.COMPLETATA) {
            return LocalDate.MAX;
        }
        try {
            long repoCount = stateTransitionConfigRepository.count();
            if (repoCount > 0 && repoCount != cache.size()) {
                log.debug("[DEBUG] StateTransitionService cache size {} differs from repo count {} -> refreshing", cache.size(), repoCount);
                refreshCache();
            }
        } catch (Exception e) {
            log.warn("[WARN] Unable to verify state transition cache consistency: {}", e.getMessage());
        }
        StateTransitionConfig config = cache.computeIfAbsent(fromState, stateTransitionConfigRepository::findByFromState);
        if (config == null) {
            log.warn("[WARN] No transition configuration found for state: {} - applying fallback {} days", fromState, DEFAULT_FALLBACK_DAYS);
            return lastStateDate.toLocalDate().plusDays(DEFAULT_FALLBACK_DAYS);
        }
        return lastStateDate.toLocalDate().plusDays(config.getDaysToTransition());
    }

    public List<StateTransitionConfig> listAllConfigs() {
        return stateTransitionConfigRepository.findAll();
    }

    public List<StateTransitionConfig> updateDaysBulk(Map<CaseState, Integer> updates) {
        if (updates == null || updates.isEmpty()) {
            return listAllConfigs();
        }
        List<StateTransitionConfig> toSave = new ArrayList<>();
        updates.forEach((fromState, days) -> {
            if (days == null || days <= 0) {
                throw new IllegalArgumentException("daysToTransition must be > 0 for state " + fromState);
            }
            StateTransitionConfig existing = stateTransitionConfigRepository.findByFromState(fromState);
            if (existing == null) {
                throw new IllegalArgumentException("No configuration found for fromState " + fromState);
            }
            existing.setDaysToTransition(days);
            toSave.add(existing);
        });
        stateTransitionConfigRepository.saveAll(toSave);
        refreshCache();
        return listAllConfigs();
    }
}
