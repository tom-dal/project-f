package com.debtcollection.dto;

import com.debtcollection.model.CaseState;
import lombok.Data;

@Data
public class StateTransitionConfigDto {
    private CaseState fromState;
    private CaseState toState;
    private Integer daysToTransition;
}

