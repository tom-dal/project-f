package com.debtcollection.repository;

import com.debtcollection.model.DebtCase;
import com.debtcollection.model.CaseState;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.time.LocalDate;
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
        String notes,
        // Date ranges (inclusive)
        LocalDate nextDeadlineFrom,
        LocalDate nextDeadlineTo,
        LocalDate currentStateFrom,
        LocalDate currentStateTo,
        LocalDate createdFrom,
        LocalDate createdTo,
        LocalDate lastModifiedFrom,
        LocalDate lastModifiedTo,
        Pageable pageable
    );
}
