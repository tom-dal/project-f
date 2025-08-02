package com.debtcollection.config;

import com.debtcollection.service.StateTransitionService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

/**
 * CUSTOM IMPLEMENTATION: Initialize StateTransitionService cache at startup
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class StateTransitionInitializer implements CommandLineRunner {

    private final StateTransitionService stateTransitionService;

    @Override
    public void run(String... args) throws Exception {
        log.info("Initializing StateTransitionService cache...");
        stateTransitionService.refreshCache();
        log.info("StateTransitionService cache initialized successfully");
    }
}
