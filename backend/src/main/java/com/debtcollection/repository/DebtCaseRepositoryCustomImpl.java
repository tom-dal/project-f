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
import java.time.LocalDate;
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
            String notes,
            LocalDate nextDeadlineFrom,
            LocalDate nextDeadlineTo,
            LocalDate currentStateFrom,
            LocalDate currentStateTo,
            LocalDate createdFrom,
            LocalDate createdTo,
            LocalDate lastModifiedFrom,
            LocalDate lastModifiedTo,
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

        // Notes substring case-insensitive
        if (notes != null && !notes.trim().isEmpty()) {
            criteria.and("notes").regex(notes.trim(), "i");
        }

        // USER PREFERENCE: Uniform single-criteria pattern for all date ranges to avoid duplicate key exception
        if (nextDeadlineFrom != null || nextDeadlineTo != null) {
            Criteria c = criteria.and("nextDeadlineDate");
            if (nextDeadlineFrom != null) {
                c.gte(nextDeadlineFrom.atStartOfDay());
            }
            if (nextDeadlineTo != null) {
                c.lt(nextDeadlineTo.plusDays(1).atStartOfDay());
            }
        }
        if (currentStateFrom != null || currentStateTo != null) {
            Criteria c = criteria.and("currentStateDate");
            if (currentStateFrom != null) {
                c.gte(currentStateFrom.atStartOfDay());
            }
            if (currentStateTo != null) {
                c.lt(currentStateTo.plusDays(1).atStartOfDay());
            }
        }
        if (createdFrom != null || createdTo != null) {
            Criteria c = criteria.and("createdDate");
            if (createdFrom != null) {
                c.gte(createdFrom.atStartOfDay());
            }
            if (createdTo != null) {
                c.lt(createdTo.plusDays(1).atStartOfDay());
            }
        }
        if (lastModifiedFrom != null || lastModifiedTo != null) {
            Criteria c = criteria.and("lastModifiedDate");
            if (lastModifiedFrom != null) {
                c.gte(lastModifiedFrom.atStartOfDay());
            }
            if (lastModifiedTo != null) {
                c.lt(lastModifiedTo.plusDays(1).atStartOfDay());
            }
        }

        Query query = new Query(criteria).with(pageable);
        List<DebtCase> debtCases = mongoTemplate.find(query, DebtCase.class);
        long total = mongoTemplate.count(new Query(criteria), DebtCase.class);
        return new PageImpl<>(debtCases, pageable, total);
    }
}
