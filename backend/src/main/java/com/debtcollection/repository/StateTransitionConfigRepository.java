package com.debtcollection.repository;

import com.debtcollection.model.CaseState;
import com.debtcollection.model.StateTransitionConfig;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.stereotype.Repository;

// USER PREFERENCE: Migrated from JpaRepository to MongoRepository
@Repository
public interface StateTransitionConfigRepository extends MongoRepository<StateTransitionConfig, String> {

    // USER PREFERENCE: Spring Data MongoDB automatically provides query methods
    StateTransitionConfig findByFromState(CaseState fromState);
}
