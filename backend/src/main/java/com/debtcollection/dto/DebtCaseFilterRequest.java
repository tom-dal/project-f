package com.debtcollection.dto;

import com.debtcollection.model.CaseState;
import lombok.Data;
import org.springframework.format.annotation.DateTimeFormat;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * DTO per i parametri di filtro delle pratiche di debt collection
 * CUSTOM IMPLEMENTATION: Supporta filtri avanzati per business logic
 */
@Data
public class DebtCaseFilterRequest {
    
    private String debtorName;
    
    // USER PREFERENCE: Supporto per filtri multipli su stato con logica OR
    private CaseState state; // Mantenuto per backward compatibility
    private List<CaseState> states; // Nuovo campo per filtri multipli OR

    private BigDecimal minAmount;
    
    private BigDecimal maxAmount;
    
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate fromDate;
    
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate toDate;
    
    private String notes;
    
    private String assignedUser;
    
    // CUSTOM IMPLEMENTATION: New boolean filters for enhanced business logic
    private Boolean hasInstallmentPlan;
    
    private Boolean paid;
    
    private Boolean ongoingNegotiations;

    // USER PREFERENCE: Filtro active per soft delete - frontend invia sempre active=true
    private Boolean active;
}
