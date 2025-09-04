package com.debtcollection.config;

import com.debtcollection.model.CaseState;
import com.debtcollection.model.StateTransitionConfig;
import com.debtcollection.repository.StateTransitionConfigRepository;
import com.debtcollection.service.StateTransitionService;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * CUSTOM IMPLEMENTATION: Seeds default state transition configurations if missing (only if collection empty).
 * Idempotent strategy: skip if any config already exists to allow manual/test custom setups.
 */
@Component
@RequiredArgsConstructor
public class StateTransitionDataInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(StateTransitionDataInitializer.class);

    private final StateTransitionConfigRepository repository;
    private final StateTransitionService stateTransitionService;

    @Override
    public void run(ApplicationArguments args) {
        long count = repository.count();
        if (count > 0) {
            log.info("[INIT] Skipping state transition seeding: repository already contains {} configs", count);
            return; // Avoid duplicates so tests / manual data remain authoritative
        }

        Map<CaseState, TransitionDef> defaults = new LinkedHashMap<>();
        defaults.put(CaseState.MESSA_IN_MORA_DA_FARE, new TransitionDef(CaseState.MESSA_IN_MORA_INVIATA, 5));
        defaults.put(CaseState.MESSA_IN_MORA_INVIATA, new TransitionDef(CaseState.DEPOSITO_RICORSO, 30));
        defaults.put(CaseState.DEPOSITO_RICORSO, new TransitionDef(CaseState.DECRETO_INGIUNTIVO_DA_NOTIFICARE, 20));
        defaults.put(CaseState.DECRETO_INGIUNTIVO_DA_NOTIFICARE, new TransitionDef(CaseState.DECRETO_INGIUNTIVO_NOTIFICATO, 15));
        defaults.put(CaseState.DECRETO_INGIUNTIVO_NOTIFICATO, new TransitionDef(CaseState.CONTESTAZIONE_DA_RISCONTRARE, 30));
        defaults.put(CaseState.CONTESTAZIONE_DA_RISCONTRARE, new TransitionDef(CaseState.PIGNORAMENTO, 45));
        defaults.put(CaseState.PIGNORAMENTO, new TransitionDef(CaseState.PRECETTO, 60));
        defaults.put(CaseState.PRECETTO, new TransitionDef(CaseState.COMPLETATA, 30));

        int created = 0;
        for (Map.Entry<CaseState, TransitionDef> e : defaults.entrySet()) {
            CaseState from = e.getKey();
            TransitionDef def = e.getValue();
            if (repository.findByFromState(from) == null) {
                StateTransitionConfig cfg = new StateTransitionConfig();
                cfg.setFromState(from);
                cfg.setToState(def.to());
                cfg.setDaysToTransition(def.days());
                repository.save(cfg);
                created++;
                log.info("[INIT] Inserted default transition {} -> {} ({} days)", from, def.to(), def.days());
            }
        }
        if (created > 0) {
            stateTransitionService.refreshCache();
            log.info("[INIT] Seed completed: {} new configs inserted", created);
        } else {
            log.info("[INIT] No default transitions inserted (all present)");
        }
    }

    private record TransitionDef(CaseState to, int days) {}
}
