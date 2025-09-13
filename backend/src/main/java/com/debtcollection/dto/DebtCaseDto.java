package com.debtcollection.dto;

import com.debtcollection.model.CaseState;
import lombok.Data;
import org.springframework.hateoas.server.core.Relation;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@Data
@Relation(collectionRelation = "cases")
public class DebtCaseDto {

    private String id; // USER PREFERENCE: Changed from Long to String for MongoDB ObjectId
    private String debtorName;
    private BigDecimal owedAmount;
    private CaseState state;
    private String notes;
    private LocalDateTime createdDate;
    private LocalDateTime updatedDate;
    private LocalDateTime lastStateDate;
    private LocalDate nextDeadlineDate;
    
    // CUSTOM IMPLEMENTATION: Auditing fields
    private String createdBy;
    private String lastModifiedBy;
    private LocalDateTime lastModifiedDate;
    
    // CUSTOM IMPLEMENTATION: New fields for enhanced business logic
    private Boolean ongoingNegotiations;
    private Boolean hasInstallmentPlan;
    private Boolean paid;
    
    // Calculated fields for frontend convenience
    private BigDecimal totalPaidAmount;
    private BigDecimal remainingAmount;
    
    private List<PaymentDto> payments;
    private List<InstallmentDto> installments;
}
