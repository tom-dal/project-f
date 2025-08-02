package com.debtcollection.repository;

import com.debtcollection.model.DebtCase;
import com.debtcollection.model.CaseState;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;

/**
 * CUSTOM IMPLEMENTATION: MongoDB custom repository implementation
 * USER PREFERENCE: Uses MongoTemplate + Criteria for maximum flexibility
 * Supports dynamic filtering with optional parameters
 */
@Repository
@RequiredArgsConstructor
public class DebtCaseRepositoryCustomImpl implements DebtCaseRepositoryCustom {

    private final MongoTemplate mongoTemplate;

    @Override
    public Page<DebtCase> findByFilters(
            String debtorName,
            CaseState state,
            List<CaseState> states,
            BigDecimal minAmount,
            BigDecimal maxAmount,
            Boolean hasInstallmentPlan,
            Boolean paid,
            Boolean ongoingNegotiations,
            Boolean active,
            Pageable pageable) {

        // USER PREFERENCE: Build dynamic criteria based on provided filters
        Criteria criteria = new Criteria();

        // Name LIKE filter (case-insensitive)
        if (debtorName != null && !debtorName.trim().isEmpty()) {
            criteria.and("debtorName").regex(debtorName.trim(), "i");
        }

        // Single state filter
        if (state != null) {
            criteria.and("currentState").is(state);
        }

        // Multiple states filter (OR logic) - takes precedence over single state
        if (states != null && !states.isEmpty()) {
            criteria.and("currentState").in(states);
        }

        // Amount range filters (GTE/LTE) - CUSTOM IMPLEMENTATION: Direct Double comparison for MongoDB
        // USER PREFERENCE: Now using Double type directly for reliable MongoDB numeric operations
        if (minAmount != null && maxAmount != null) {
            // Both min and max: direct Double comparison
            criteria.and("owedAmount").gte(minAmount.doubleValue()).lte(maxAmount.doubleValue());
        } else if (minAmount != null) {
            // Only min amount: direct Double comparison
            criteria.and("owedAmount").gte(minAmount.doubleValue());
        } else if (maxAmount != null) {
            // Only max amount: direct Double comparison
            criteria.and("owedAmount").lte(maxAmount.doubleValue());
        }

        // Boolean filters
        if (hasInstallmentPlan != null) {
            criteria.and("hasInstallmentPlan").is(hasInstallmentPlan);
        }
        if (paid != null) {
            criteria.and("paid").is(paid);
        }
        if (ongoingNegotiations != null) {
            criteria.and("ongoingNegotiations").is(ongoingNegotiations);
        }

        // Active filter (soft delete) - defaults to true if not specified
        if (active != null) {
            criteria.and("active").is(active);
        } else {
            // USER PREFERENCE: Default to active=true for soft delete pattern
            criteria.and("active").is(true);
        }

        // Build query with criteria and pagination
        Query query = new Query(criteria).with(pageable);

        // Execute query
        List<DebtCase> debtCases = mongoTemplate.find(query, DebtCase.class);

        // Get total count for pagination
        Query countQuery = new Query(criteria);
        long total = mongoTemplate.count(countQuery, DebtCase.class);

        return new PageImpl<>(debtCases, pageable, total);
    }
}
