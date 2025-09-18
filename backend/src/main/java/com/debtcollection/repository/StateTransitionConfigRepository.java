package com.debtcollection.repository;

import com.debtcollection.model.CaseState;
import com.debtcollection.model.StateTransitionConfig;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface StateTransitionConfigRepository extends MongoRepository<StateTransitionConfig, String> {

    StateTransitionConfig findByFromState(CaseState fromState);
}
