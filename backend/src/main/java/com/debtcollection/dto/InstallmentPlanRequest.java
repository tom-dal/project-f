package com.debtcollection.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Min;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
public class InstallmentPlanRequest {

    @NotNull(message = "Number of installments is required")
    @Min(value = 1, message = "Number of installments must be at least 1")
    private Integer numberOfInstallments;

    @NotNull(message = "First installment due date is required")
    private LocalDateTime firstInstallmentDueDate;

    @NotNull(message = "Installment amount is required")
    @Positive(message = "Installment amount must be positive")
    private BigDecimal installmentAmount;

    // Optional: frequency in days between installments (default 30 days)
    @Min(value = 1, message = "Frequency must be at least 1 day")
    private Integer frequencyDays = 30;
}
