package com.debtcollection.model;

import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.*;
import org.springframework.data.mongodb.core.mapping.Document;
import org.springframework.data.mongodb.core.mapping.Field;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.CompoundIndexes;

import java.time.LocalDateTime;
import java.util.List;
import java.util.ArrayList;

// USER PREFERENCE: Migrated from JPA @Entity to MongoDB @Document
@Document(collection = "debt_cases")
@Data
@NoArgsConstructor
// USER PREFERENCE: MongoDB compound indexes for optimizing common queries in debt collection system
@CompoundIndexes({
    // Main indexes for active field (soft delete)
    @CompoundIndex(name = "idx_debt_case_active", def = "{'active': 1}"),
    @CompoundIndex(name = "idx_debt_case_active_state", def = "{'active': 1, 'currentState': 1}"),

    // USER PREFERENCE: Critical index for deadlines on active cases
    @CompoundIndex(name = "idx_debt_case_active_deadline", def = "{'active': 1, 'nextDeadlineDate': 1}"),
    @CompoundIndex(name = "idx_debt_case_active_state_deadline", def = "{'active': 1, 'currentState': 1, 'nextDeadlineDate': 1}"),

    // Single indexes for backward compatibility
    @CompoundIndex(name = "idx_debt_case_state", def = "{'currentState': 1}"),
    @CompoundIndex(name = "idx_debt_case_deadline", def = "{'nextDeadlineDate': 1}")
})
public class DebtCase {

    @Id
    private String id;

    @Field("debtor_name")
    @Indexed
    private String debtorName;

    @Field("owed_amount")
    private Double owedAmount;

    @Field("current_state")
    private CaseState currentState;

    @Field("current_state_date")
    private LocalDateTime currentStateDate;

    @Field("next_deadline_date")
    private LocalDateTime nextDeadlineDate;

    @Field("ongoing_negotiations")
    private Boolean ongoingNegotiations;

    @Field("has_installment_plan")
    private Boolean hasInstallmentPlan = false;

    private Boolean paid = false;

    // USER PREFERENCE: Field to indicate if the case is active or not (soft delete)
    private Boolean active = true;

    private String notes;

    // Audit fields
    @CreatedDate
    @Field("created_date")
    private LocalDateTime createdDate;

    @LastModifiedDate
    @Field("last_modified_date")
    private LocalDateTime lastModifiedDate;

    @CreatedBy
    @Field("created_by")
    private String createdBy;

    @LastModifiedBy
    @Field("last_modified_by")
    private String lastModifiedBy;

    // USER PREFERENCE: MongoDB approach - embed related collections as arrays
    // This replaces JPA @OneToMany relationships
    private List<Installment> installments = new ArrayList<>();

    // CUSTOM IMPLEMENTATION: Embedded payments instead of separate collection
    private List<Payment> payments = new ArrayList<>();

}