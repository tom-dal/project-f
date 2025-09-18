package com.debtcollection.controller;

import com.debtcollection.dto.StateTransitionConfigDto;
import com.debtcollection.model.CaseState;
import com.debtcollection.model.StateTransitionConfig;
import com.debtcollection.service.StateTransitionService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/state-transitions")
@RequiredArgsConstructor
@Slf4j
public class StateTransitionController {

    private final StateTransitionService stateTransitionService;

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<StateTransitionConfigDto>> listAll() {
        List<StateTransitionConfigDto> list = stateTransitionService.listAllConfigs().stream()
                .map(this::toDto)
                .collect(Collectors.toList());
        return ResponseEntity.ok(list);
    }

    @PutMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<?> updateBulk(@Valid @RequestBody List<UpdateStateTransitionRequest> requests) {
        try {
            Map<CaseState, Integer> updates = requests.stream()
                    .collect(Collectors.toMap(UpdateStateTransitionRequest::fromState, UpdateStateTransitionRequest::daysToTransition));
            List<StateTransitionConfigDto> updated = stateTransitionService.updateDaysBulk(updates).stream()
                    .map(this::toDto)
                    .collect(Collectors.toList());
            return ResponseEntity.ok(updated);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage(), "error", "IllegalArgumentException"));
        }
    }

    private StateTransitionConfigDto toDto(StateTransitionConfig cfg) {
        StateTransitionConfigDto dto = new StateTransitionConfigDto();
        dto.setFromState(cfg.getFromState());
        dto.setToState(cfg.getToState());
        dto.setDaysToTransition(cfg.getDaysToTransition());
        return dto;
    }

    public record UpdateStateTransitionRequest(
            @NotNull(message = "fromState required") CaseState fromState,
            @NotNull(message = "daysToTransition required") Integer daysToTransition
    ) {}
}
