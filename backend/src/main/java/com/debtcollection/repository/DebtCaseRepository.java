package com.debtcollection.repository;

import com.debtcollection.model.DebtCase;
import com.debtcollection.model.CaseState;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

// USER PREFERENCE: Migrated from JpaRepository to MongoRepository + Custom interface
@Repository
public interface DebtCaseRepository extends MongoRepository<DebtCase, String>, DebtCaseRepositoryCustom {

    /**
     * CUSTOM IMPLEMENTATION: Trova tutti i DebtCase con stato corrente specifico
     * USER PREFERENCE: Migrated from JPQL to MongoDB query
     */
    @Query("{'currentState': ?0}")
    List<DebtCase> findAllByState(CaseState state);

    // USER PREFERENCE: Spring Data MongoDB automatically provides query methods
    List<DebtCase> findByCurrentState(CaseState state);

    // Method used by summary query (excludes COMPLETATA)
    List<DebtCase> findByCurrentStateNot(CaseState state);
}
