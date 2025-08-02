package com.debtcollection.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
public class PaymentDto {

    private String id; // USER PREFERENCE: Changed from Long to String for MongoDB embedded document ID
    private BigDecimal amount; // USER PREFERENCE: BigDecimal for monetary precision in DTOs

    @JsonFormat(pattern = "yyyy-MM-dd")
    private LocalDate paymentDate;

    private String debtCaseId; // USER PREFERENCE: Changed from Long to String for MongoDB ObjectId
    private LocalDateTime createdDate;
    private LocalDateTime lastModifiedDate;
}
