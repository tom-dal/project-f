package com.debtcollection.dto;

import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

@Data
@NoArgsConstructor
public class InstallmentPlanResponse {
    private String debtCaseId; // USER PREFERENCE: Changed from Long to String for MongoDB ObjectId
    private Integer numberOfInstallments;
    private LocalDateTime nextDeadlineDate;
    private List<InstallmentDto> installments;
    private LocalDateTime createdDate;
}
