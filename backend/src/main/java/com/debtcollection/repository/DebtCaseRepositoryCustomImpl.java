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
import java.time.LocalDateTime;
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
            String notes,
            LocalDateTime nextDeadlineFrom,
            LocalDateTime nextDeadlineTo,
            LocalDateTime currentStateFrom,
            LocalDateTime currentStateTo,
            LocalDateTime createdFrom,
            LocalDateTime createdTo,
            LocalDateTime lastModifiedFrom,
            LocalDateTime lastModifiedTo,
            Pageable pageable) {

        Criteria criteria = new Criteria();

        if (debtorName != null && !debtorName.trim().isEmpty()) {
            criteria.and("debtorName").regex(debtorName.trim(), "i");
        }

        if (state != null) {
            criteria.and("currentState").is(state);
        }

        if (states != null && !states.isEmpty()) {
            criteria.and("currentState").in(states);
        }

        if (minAmount != null && maxAmount != null) {
            criteria.and("owedAmount").gte(minAmount.doubleValue()).lte(maxAmount.doubleValue());
        } else if (minAmount != null) {
            criteria.and("owedAmount").gte(minAmount.doubleValue());
        } else if (maxAmount != null) {
            criteria.and("owedAmount").lte(maxAmount.doubleValue());
        }

        if (hasInstallmentPlan != null) {
            criteria.and("hasInstallmentPlan").is(hasInstallmentPlan);
        }
        if (paid != null) {
            criteria.and("paid").is(paid);
        }
        if (ongoingNegotiations != null) {
            criteria.and("ongoingNegotiations").is(ongoingNegotiations);
        }

        if (active != null) {
            criteria.and("active").is(active);
        } else {
            criteria.and("active").is(true); // USER PREFERENCE: default active=true
        }

        // Notes substring case-insensitive
        if (notes != null && !notes.trim().isEmpty()) {
            criteria.and("notes").regex(notes.trim(), "i");
        }

        // Date ranges (inclusive)
        applyDateRange(criteria, "nextDeadlineDate", nextDeadlineFrom, nextDeadlineTo);
        applyDateRange(criteria, "currentStateDate", currentStateFrom, currentStateTo);
        applyDateRange(criteria, "createdDate", createdFrom, createdTo);
        applyDateRange(criteria, "lastModifiedDate", lastModifiedFrom, lastModifiedTo);

        Query query = new Query(criteria).with(pageable);
        List<DebtCase> debtCases = mongoTemplate.find(query, DebtCase.class);
        long total = mongoTemplate.count(new Query(criteria), DebtCase.class);
        return new PageImpl<>(debtCases, pageable, total);
    }

    private void applyDateRange(Criteria baseCriteria, String fieldName, LocalDateTime from, LocalDateTime to) {
        if (from != null && to != null) {
            baseCriteria.and(fieldName).gte(from).lte(to);
        } else if (from != null) {
            baseCriteria.and(fieldName).gte(from);
        } else if (to != null) {
            baseCriteria.and(fieldName).lte(to);
        }
    }
}
