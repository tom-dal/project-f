package com.debtcollection.dto;

import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
public class InstallmentPaymentRequest {

    @NotNull(message = "Payment amount is required")
    @Positive(message = "Payment amount must be positive")
    private BigDecimal amount;

    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME)
    private LocalDateTime paymentDate;
}
