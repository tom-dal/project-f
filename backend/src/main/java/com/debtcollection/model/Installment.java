package com.debtcollection.model;

import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.mongodb.core.mapping.Field;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
public class Installment {

    private String installmentId; // Internal ID for referencing within the embedded array

    @Field("installment_number")
    private Integer installmentNumber;

    private BigDecimal amount;

    @Field("due_date")
    private LocalDateTime dueDate;

    private Boolean paid = false;

    @Field("paid_date")
    private LocalDateTime paidDate;

    @Field("paid_amount")
    private BigDecimal paidAmount;

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
