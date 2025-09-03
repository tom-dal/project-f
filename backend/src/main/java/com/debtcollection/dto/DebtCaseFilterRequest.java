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
    private CaseState state; // Backward compatibility singolo stato
    private List<CaseState> states; // Stati multipli OR

    private BigDecimal minAmount;
    private BigDecimal maxAmount;

    // CUSTOM IMPLEMENTATION: Notes substring search (case-insensitive)
    private String notes;

    // USER PREFERENCE: Boolean filters
    private Boolean hasInstallmentPlan;
    private Boolean paid;
    private Boolean ongoingNegotiations;

    // USER PREFERENCE: Range date dedicati (inclusivi) per i diversi campi data
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate nextDeadlineFrom;
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate nextDeadlineTo;

    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate currentStateFrom;
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate currentStateTo;

    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate createdFrom;
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate createdTo;

    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate lastModifiedFrom;
    @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
    private LocalDate lastModifiedTo;
}
