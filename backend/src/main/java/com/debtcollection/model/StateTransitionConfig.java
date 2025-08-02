package com.debtcollection.model;

import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import org.springframework.data.mongodb.core.mapping.Field;
import org.springframework.data.mongodb.core.index.Indexed;

@Document(collection = "state_transition_configs")
@Data
@NoArgsConstructor
public class StateTransitionConfig {

    @Id
    private String id;

    @Field("from_state")
    @Indexed
    private CaseState fromState;

    @Field("to_state")
    private CaseState toState;

    @Field("days_to_transition")
    private Integer daysToTransition;
}
