package com.debtcollection.model;

import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.mongodb.core.mapping.Field;

import java.time.LocalDate;
import java.time.LocalDateTime;

// USER PREFERENCE: Migrated from JPA @Entity to MongoDB embedded document
// No longer a separate collection - embedded in DebtCase
@Data
@NoArgsConstructor
public class Payment {

    // USER PREFERENCE: No @Id needed - embedded document, not separate collection
    private String paymentId; // Internal ID for referencing within the embedded array

    @Field("payment_date")
    private LocalDate paymentDate;

    private Double amount;

    // CUSTOM IMPLEMENTATION: Reference to installment by ID instead of JPA @OneToOne
    @Field("installment_id")
    private String installmentId; // Reference to installment within same DebtCase

    // Audit fields - USER PREFERENCE: Embedded audit tracking
    @Field("created_date")
    private LocalDateTime createdDate;

    @Field("last_modified_date")
    private LocalDateTime lastModifiedDate;

    @Field("created_by")
    private String createdBy;

    @Field("last_modified_by")
    private String lastModifiedBy;
}
