package com.debtcollection.dto;

import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
public class InstallmentDto {
    private String id; // USER PREFERENCE: Changed from Long to String for MongoDB embedded document ID
    private String debtCaseId; // USER PREFERENCE: Changed from Long to String for MongoDB ObjectId
    private Integer installmentNumber;
    private BigDecimal amount;
    private LocalDateTime dueDate;
    private Boolean paid;
    private LocalDateTime paidDate;
    private BigDecimal paidAmount;
    private LocalDateTime createdDate;
    private LocalDateTime lastModifiedDate;
}