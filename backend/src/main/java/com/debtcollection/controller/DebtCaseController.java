package com.debtcollection.controller;

import com.debtcollection.assembler.PagedDebtCaseAssembler;
import com.debtcollection.dto.DebtCaseDto;
import com.debtcollection.dto.DebtCaseFilterRequest;
import com.debtcollection.dto.PaymentDto;
import com.debtcollection.dto.InstallmentPlanRequest;
import com.debtcollection.dto.InstallmentPlanResponse;
import com.debtcollection.dto.InstallmentPaymentRequest;
import com.debtcollection.model.CaseState;
import com.debtcollection.service.DebtCaseService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.hateoas.EntityModel;
import org.springframework.hateoas.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Map;

@RestController
@RequestMapping("/cases")
@RequiredArgsConstructor
@Slf4j
public class DebtCaseController {

    private final DebtCaseService debtCaseService;
    private final PagedDebtCaseAssembler pagedDebtCaseAssembler;

    /**
     * Retrieves debt cases with optional filtering and pagination.
     * If no filter parameters are provided, returns all cases.
     * 
     * Supports filtering by:
     * - debtorName: partial search (case-insensitive)
     * - state / states: stato singolo o lista OR
     * - minAmount / maxAmount: range importo (inclusivo) con validazione min<=max
     * - notes: substring case-insensitive
     * - hasInstallmentPlan / paid / ongoingNegotiations / active
     * - nextDeadlineFrom/To, currentStateFrom/To, createdFrom/To, lastModifiedFrom/To (range inclusivi per ciascun campo data)
     *
     * Pagination and Sorting:
     * Spring Boot automatically binds request parameters to Pageable:
     * - page: page number (0-based, default: 0)
     * - size: page size (default: 20, max: 100)
     * - sort: sort criteria (format: property,direction e.g., "nextDeadlineDate,asc")
     * 
     * AVAILABLE SORTING FIELDS (Frontend Reference):
     * - debtorName: alphabetical sorting
     * - owedAmount: amount-based priority
     * - currentState: state-based grouping
     * - currentStateDate: recent activity first
     * - nextDeadlineDate: urgency-based (RECOMMENDED default)
     * - ongoingNegotiations: active negotiations first
     * - hasInstallmentPlan: installment cases grouping
     * - paid: payment status grouping
     * 
     * Examples:
     * - /api/v1/cases?page=0&size=10&sort=nextDeadlineDate,asc (urgent first)
     * - /api/v1/cases?paid=false&sort=owedAmount,desc (unpaid, high amounts)
     * - /api/v1/cases?sort=debtorName,asc&sort=owedAmount,desc (multiple sorts)
     * - /api/v1/cases?hasInstallmentPlan=true&sort=nextDeadlineDate,asc (installments by urgency)
     * 
     * FRONTEND UI SUGGESTIONS:
     * - Default sort: nextDeadlineDate,asc (shows urgent cases first)
     * - Sort dropdown: [Urgency, Amount, Recent, Name]
     * - ASC/DESC toggle with ↑↓ icons
     * - Combine filters + sorting for optimal UX
     */
    @GetMapping
    public ResponseEntity<?> getCases(
            DebtCaseFilterRequest filterRequest,
            Pageable pageable
    ) {
        if (filterRequest.getMinAmount() != null && filterRequest.getMaxAmount() != null &&
            filterRequest.getMinAmount().compareTo(filterRequest.getMaxAmount()) > 0) {
            return ResponseEntity.badRequest().body(Map.of(
                "message", "L'importo minimo non può essere maggiore dell'importo massimo",
                "error", "IllegalArgumentException"
            ));
        }
        Page<DebtCaseDto> casePage = debtCaseService.findWithFilters(filterRequest, pageable);
        PagedModel<EntityModel<DebtCaseDto>> response = pagedDebtCaseAssembler.toPagedModel(casePage, filterRequest);
        return ResponseEntity.ok(response);
    }

    @PostMapping
    public ResponseEntity<DebtCaseDto> createDebtCase(
            @Valid @RequestBody CreateDebtCaseRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        return ResponseEntity.ok(debtCaseService.createDebtCase(
            request.debtorName(),
            request.initialState(),
            request.lastStateDate(),
            request.amount()
        ));
    }

    @PutMapping("/{id}")
    public ResponseEntity<DebtCaseDto> updateDebtCase(
            @PathVariable String id, // USER PREFERENCE: Changed from Long to String for MongoDB
            @Valid @RequestBody UpdateDebtCaseRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        return ResponseEntity.ok(debtCaseService.updateDebtCase(
            id,
            request.debtorName(),
            request.owedAmount(),
            request.currentState(),
            request.nextDeadlineDate(),
            request.ongoingNegotiations(),
            request.hasInstallmentPlan(),
            request.paid(),
            request.notes(),
            request.clearNotes()
        ));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteDebtCase(
            @PathVariable String id, // USER PREFERENCE: Changed from Long to String for MongoDB
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        debtCaseService.deleteDebtCase(id);
        return ResponseEntity.noContent().build();
    }

    /**
     * Register a payment for a debt case
     * Automatically updates case state to COMPLETED if fully paid
     */
    @PostMapping("/{id}/payments")
    public ResponseEntity<?> registerPayment(
            @PathVariable String id, // USER PREFERENCE: Changed from Long to String for MongoDB
            @RequestBody RegisterPaymentRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        try {
            PaymentDto payment = debtCaseService.registerPayment(
                id,
                request.amount(),
                request.paymentDate()
            );
            return ResponseEntity.ok(payment);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest()
                .body(Map.of("message", e.getMessage(), "error", "IllegalArgumentException"));
        }
    }

    /**
     * Create an installment plan for a debt case
     * Updates the nextDeadlineDate to the first installment due date
     */
    @PostMapping("/{id}/installment-plan")
    public ResponseEntity<?> createInstallmentPlan(
            @PathVariable String id, // USER PREFERENCE: Changed from Long to String for MongoDB
            @Valid @RequestBody InstallmentPlanRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        try {
            InstallmentPlanResponse response = debtCaseService.createInstallmentPlan(id, request);
            return ResponseEntity.ok(response);
        } catch (IllegalStateException e) {
            return ResponseEntity.badRequest()
                .body(Map.of("message", e.getMessage(), "error", "IllegalStateException"));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest()
                .body(Map.of("message", e.getMessage(), "error", "RuntimeException"));
        }
    }

    /**
     * Register a payment for a specific installment
     * Updates the installment as paid and updates nextDeadlineDate to next unpaid installment
     */
    @PostMapping("/{id}/installments/{installmentId}/payments")
    public ResponseEntity<?> registerInstallmentPayment(
            @PathVariable String id, // USER PREFERENCE: Changed from Long to String for MongoDB
            @PathVariable String installmentId, // USER PREFERENCE: Changed from Long to String for MongoDB
            @Valid @RequestBody InstallmentPaymentRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        try {
            PaymentDto payment = debtCaseService.registerInstallmentPayment(
                id,
                installmentId,
                request.getAmount(),
                request.getPaymentDate()
            );
            return ResponseEntity.ok(payment);
        } catch (IllegalArgumentException | IllegalStateException e) {
            return ResponseEntity.badRequest()
                .body(Map.of("message", e.getMessage(), "error", e.getClass().getSimpleName()));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest()
                .body(Map.of("message", e.getMessage(), "error", "RuntimeException"));
        }
    }

    public record CreateDebtCaseRequest(
        @NotBlank(message = "Debtor name is required")
        @Size(min = 2, max = 255, message = "Debtor name must be between 2 and 255 characters")
        String debtorName,
        CaseState initialState,
        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE)
        LocalDateTime lastStateDate,
        @NotNull(message = "Amount is required")
        @Positive(message = "Amount must be greater than zero")
        @DecimalMax(value = "999999999.99", message = "Amount cannot exceed 999,999,999.99")
        BigDecimal amount
    ) {}

    public record UpdateDebtCaseRequest(
        String debtorName,                    // ✅ Modificabile
        BigDecimal owedAmount,                // ✅ Modificabile  
        CaseState currentState,               // ✅ Modificabile (currentStateDate si aggiorna automaticamente)
        LocalDateTime nextDeadlineDate,      // ✅ Modificabile
        Boolean ongoingNegotiations,         // ✅ Modificabile
        Boolean hasInstallmentPlan,          // ✅ Modificabile  
        Boolean paid,                        // ✅ Modificabile
        String notes,                        // ✅ Modificabile
        Boolean clearNotes                   // ✅ Flag per settare notes a null
        // ❌ NON INCLUSI:
        // - id: non modificabile
        // - currentStateDate: si aggiorna automaticamente con currentState
        // - installments/payments: gestiti con endpoint dedicati
    ) {}

    public record RegisterPaymentRequest(
        BigDecimal amount,
        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME)
        LocalDateTime paymentDate
    ) {}
}
