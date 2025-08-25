package com.debtcollection.repository;

import com.debtcollection.model.DebtCase;
import com.debtcollection.model.CaseState;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * USER PREFERENCE: Custom repository interface for complex MongoDB queries
 * CUSTOM IMPLEMENTATION: Esteso con filtri notes e range date dedicati
 */
public interface DebtCaseRepositoryCustom {

    /**
     * CUSTOM IMPLEMENTATION: Find debt cases with flexible filters
     * Supports all existing filters: name like, state, date ranges, etc.
     */
    Page<DebtCase> findByFilters(
        String debtorName,           // LIKE case-insensitive
        CaseState state,             // Single state
        List<CaseState> states,      // Multiple states (OR logic)
        BigDecimal minAmount,        // Amount GTE
        BigDecimal maxAmount,        // Amount LTE
        Boolean hasInstallmentPlan,
        Boolean paid,
        Boolean ongoingNegotiations,
        Boolean active,              // Soft delete
        String notes,
        // Date ranges (inclusive)
        LocalDateTime nextDeadlineFrom,
        LocalDateTime nextDeadlineTo,
        LocalDateTime currentStateFrom,
        LocalDateTime currentStateTo,
        LocalDateTime createdFrom,
        LocalDateTime createdTo,
        LocalDateTime lastModifiedFrom,
        LocalDateTime lastModifiedTo,
        Pageable pageable
    );
}
