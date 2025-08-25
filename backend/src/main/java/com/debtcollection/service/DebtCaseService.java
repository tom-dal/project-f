package com.debtcollection.service;

import com.debtcollection.dto.DebtCaseDto;
import com.debtcollection.dto.DebtCaseFilterRequest;
import com.debtcollection.dto.PaymentDto;
import com.debtcollection.dto.InstallmentPlanRequest;
import com.debtcollection.dto.InstallmentPlanResponse;
import com.debtcollection.dto.InstallmentDto;
import com.debtcollection.mapper.DebtCaseMapper;
import com.debtcollection.mapper.PaymentMapper;
import com.debtcollection.mapper.InstallmentMapper;
import com.debtcollection.model.*;
import com.debtcollection.repository.DebtCaseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.LocalDate;
import java.util.List;
import java.util.ArrayList;
import java.util.Optional;
import java.util.UUID;

// USER PREFERENCE: Migrated from JPA to MongoDB - removed InstallmentRepository, Specification
@Service
@RequiredArgsConstructor
public class DebtCaseService {

    private final DebtCaseRepository debtCaseRepository;
    private final DebtCaseMapper debtCaseMapper;
    private final PaymentMapper paymentMapper;
    private final InstallmentMapper installmentMapper;
    // USER PREFERENCE: Removed InstallmentRepository - now installments are embedded in DebtCase
    private final StateTransitionService stateTransitionService;

    @Transactional
    public DebtCaseDto createDebtCase(String debtorName, CaseState state, LocalDateTime lastStateDate, BigDecimal amount) {
        DebtCase debtCase = new DebtCase();
        debtCase.setDebtorName(debtorName);
        debtCase.setOwedAmount(amount.doubleValue()); // USER PREFERENCE: Conversione BigDecimal -> Double per MongoDB

        // Imposta lo stato corrente direttamente
        debtCase.setCurrentState(state);
        LocalDateTime currentStateDate = lastStateDate != null ? lastStateDate : LocalDateTime.now();
        debtCase.setCurrentStateDate(currentStateDate);
        
        // Initialize boolean fields
        debtCase.setHasInstallmentPlan(false);
        debtCase.setPaid(false);
        debtCase.setOngoingNegotiations(false);
        
        // CUSTOM IMPLEMENTATION: Calculate next_deadline_date using StateTransitionService
        if (state != CaseState.COMPLETATA) {
            LocalDate nextDeadline = stateTransitionService.calculateNextDeadline(state, currentStateDate);
            if (nextDeadline != null) {
                debtCase.setNextDeadlineDate(nextDeadline.atStartOfDay());
            } else {
                // Fallback: set to 30 days from current state date
                debtCase.setNextDeadlineDate(currentStateDate.plusDays(30));
            }
        } else {
            // For completed cases, set next deadline to null or current date
            debtCase.setNextDeadlineDate(currentStateDate);
        }
        
        // CUSTOM IMPLEMENTATION: JPA validator will run automatically via @PrePersist
        debtCase = debtCaseRepository.save(debtCase);

        return debtCaseMapper.toDto(debtCase);
    }

    @Transactional
    public DebtCaseDto updateDebtCase(String id, String debtorName, BigDecimal owedAmount,
                                      CaseState currentState, LocalDateTime nextDeadlineDate,
                                      Boolean ongoingNegotiations, Boolean hasInstallmentPlan,
                                      Boolean paid, String notes, Boolean clearNotes) {
        DebtCase debtCase = debtCaseRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("DebtCase not found with id: " + id));
        
        // CUSTOM IMPLEMENTATION: Update expandido con tutti i campi modificabili
        // Aggiorna debtorName se fornito
        if (debtorName != null) {
            debtCase.setDebtorName(debtorName);
        }
        
        // Aggiorna owedAmount se fornito
        if (owedAmount != null) {
            debtCase.setOwedAmount(owedAmount.doubleValue()); // USER PREFERENCE: Conversione BigDecimal -> Double per MongoDB
        }
        
        // Aggiorna stato solo se diverso (currentStateDate si aggiorna automaticamente)
        if (currentState != null && (debtCase.getCurrentState() == null || !currentState.equals(debtCase.getCurrentState()))) {
            debtCase.setCurrentState(currentState);
            LocalDateTime newStateDate = LocalDateTime.now();
            debtCase.setCurrentStateDate(newStateDate); // ⏰ Automatico
            
            // CUSTOM IMPLEMENTATION: Calculate next_deadline_date using StateTransitionService
            if (currentState != CaseState.COMPLETATA) {
                LocalDate nextDeadline = stateTransitionService.calculateNextDeadline(currentState, newStateDate);
                if (nextDeadline != null) {
                    debtCase.setNextDeadlineDate(nextDeadline.atStartOfDay());
                } else {
                    // Fallback: set to 30 days from new state date
                    debtCase.setNextDeadlineDate(newStateDate.plusDays(30));
                }
            } else {
                // For completed cases, set next deadline to current date
                debtCase.setNextDeadlineDate(newStateDate);
            }
        }
        
        // Aggiorna nextDeadlineDate se fornito
        if (nextDeadlineDate != null) {
            debtCase.setNextDeadlineDate(nextDeadlineDate);
        }
        
        // Aggiorna ongoingNegotiations se fornito
        if (ongoingNegotiations != null) {
            debtCase.setOngoingNegotiations(ongoingNegotiations);
        }
        
        // Aggiorna hasInstallmentPlan se fornito
        if (hasInstallmentPlan != null) {
            debtCase.setHasInstallmentPlan(hasInstallmentPlan);
        }
        
        // Aggiorna paid se fornito
        if (paid != null) {
            debtCase.setPaid(paid);
        }
        
        // CUSTOM IMPLEMENTATION: Gestione notes con flag clearNotes
        if (clearNotes != null && clearNotes) {
            // clearNotes ha priorità: setta esplicitamente a null
            debtCase.setNotes(null);
        } else if (notes != null) {
            // Se clearNotes non è true, aggiorna normalmente
            debtCase.setNotes(notes);
        }
        // Se clearNotes è false/null E notes è null → non toccare (mantieni valore precedente)
        
        return debtCaseMapper.toDto(debtCaseRepository.save(debtCase));
    }

    @Transactional
    public void deleteDebtCase(String id) {
        if (!debtCaseRepository.existsById(id)) {
            throw new RuntimeException("DebtCase not found with id: " + id);
        }
        debtCaseRepository.deleteById(id);
    }

    /**
     * Find debt cases with filters and pagination support.
     * Default sort: currentStateDate desc (most recent first)
     * CUSTOM IMPLEMENTATION: Supports advanced business logic filtering
     */
    public Page<DebtCaseDto> findWithFilters(DebtCaseFilterRequest filterRequest, Pageable pageable) {
        return debtCaseRepository.findByFilters(
            filterRequest.getDebtorName(),
            filterRequest.getState(),
            filterRequest.getStates(),
            filterRequest.getMinAmount(),
            filterRequest.getMaxAmount(),
            filterRequest.getHasInstallmentPlan(),
            filterRequest.getPaid(),
            filterRequest.getOngoingNegotiations(),
            filterRequest.getActive(),
            filterRequest.getNotes(),
            filterRequest.getNextDeadlineFrom(),
            filterRequest.getNextDeadlineTo(),
            filterRequest.getCurrentStateFrom(),
            filterRequest.getCurrentStateTo(),
            filterRequest.getCreatedFrom(),
            filterRequest.getCreatedTo(),
            filterRequest.getLastModifiedFrom(),
            filterRequest.getLastModifiedTo(),
            pageable
        ).map(debtCaseMapper::toDto);
    }

    /**
     * Register a payment for a debt case
     * USER PREFERENCE: Payment registration with automatic case state evaluation
     */
    @Transactional
    public PaymentDto registerPayment(String debtCaseId, BigDecimal amount, LocalDateTime paymentDate) {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Payment amount must be greater than zero");
        }
        
        LocalDate paymentLocalDate = paymentDate != null ? 
            paymentDate.toLocalDate() : LocalDate.now();

        DebtCase debtCase = debtCaseRepository.findById(debtCaseId)
                .orElseThrow(() -> new RuntimeException("DebtCase not found with id: " + debtCaseId));

        // USER PREFERENCE: Payment is now embedded in DebtCase
        Payment payment = new Payment();
        payment.setPaymentId(UUID.randomUUID().toString()); // Internal ID for embedded document
        payment.setAmount(amount.doubleValue()); // USER PREFERENCE: Convert BigDecimal (DTO) to Double (MongoDB)
        payment.setPaymentDate(paymentLocalDate);
        payment.setCreatedDate(LocalDateTime.now());
        payment.setLastModifiedDate(LocalDateTime.now());
        payment.setCreatedBy("system"); // TODO: get from security context
        payment.setLastModifiedBy("system"); // TODO: get from security context

        // Add payment to debt case embedded collection
        debtCase.getPayments().add(payment);

        Double totalPaid = calculateTotalPaidAmount(debtCase);
        
        // Auto-complete case when fully paid
        if (totalPaid.compareTo(debtCase.getOwedAmount()) >= 0 &&
            debtCase.getCurrentState() != CaseState.COMPLETATA) {
            debtCase.setNotes("Case automatically marked as COMPLETATA after payment registration");
            
            // Aggiorna i campi diretti
            debtCase.setCurrentState(CaseState.COMPLETATA);
            LocalDateTime completionDate = LocalDateTime.now();
            debtCase.setCurrentStateDate(completionDate);
            debtCase.setPaid(true);
            
            // CUSTOM IMPLEMENTATION: Set next deadline for completed case
            debtCase.setNextDeadlineDate(completionDate);
        }

        debtCaseRepository.save(debtCase);

        // USER PREFERENCE: Fix per popolare debtCaseId nel response
        PaymentDto paymentDto = paymentMapper.toDto(payment);
        paymentDto.setDebtCaseId(debtCaseId);
        return paymentDto;
    }

    public Double calculateTotalPaidAmount(DebtCase debtCase) {
        return debtCase.getPayments().stream()
                .map(Payment::getAmount)
                .reduce(0.0, Double::sum);
    }

    /**
     * Create an installment plan for a debt case
     * USER PREFERENCE: Installments are now embedded in DebtCase
     */
    @Transactional
    public InstallmentPlanResponse createInstallmentPlan(String debtCaseId, InstallmentPlanRequest request) {
        DebtCase debtCase = debtCaseRepository.findById(debtCaseId)
                .orElseThrow(() -> new RuntimeException("DebtCase not found with id: " + debtCaseId));

        // Validate that the case doesn't already have an installment plan
        if (debtCase.getHasInstallmentPlan()) {
            throw new IllegalStateException("DebtCase already has an installment plan");
        }

        // Validate that the case is not already completed or paid
        if (debtCase.getCurrentState() == CaseState.COMPLETATA || debtCase.getPaid()) {
            throw new IllegalStateException("Cannot create installment plan for completed or paid cases");
        }

        // Clear any existing installments (in case of recreating plan)
        debtCase.getInstallments().clear();

        // Create installments as embedded documents
        List<Installment> installments = new ArrayList<>();
        LocalDateTime currentDueDate = request.getFirstInstallmentDueDate();

        for (int i = 1; i <= request.getNumberOfInstallments(); i++) {
            Installment installment = new Installment();
            installment.setInstallmentId(UUID.randomUUID().toString()); // Internal ID for embedded document
            installment.setInstallmentNumber(i);
            installment.setAmount(request.getInstallmentAmount());
            installment.setDueDate(currentDueDate);
            installment.setPaid(false);
            installment.setCreatedDate(LocalDateTime.now());
            installment.setLastModifiedDate(LocalDateTime.now());
            installment.setCreatedBy("system"); // TODO: get from security context
            installment.setLastModifiedBy("system"); // TODO: get from security context

            installments.add(installment);
            debtCase.getInstallments().add(installment);

            // Calculate next due date
            currentDueDate = currentDueDate.plusDays(request.getFrequencyDays());
        }

        // Update debt case
        debtCase.setHasInstallmentPlan(true);
        debtCase.setNextDeadlineDate(request.getFirstInstallmentDueDate());

        // Save the debt case (this will save embedded installments)
        debtCase = debtCaseRepository.save(debtCase);

        // Build response
        InstallmentPlanResponse response = new InstallmentPlanResponse();
        response.setDebtCaseId(debtCaseId);
        response.setNumberOfInstallments(request.getNumberOfInstallments());
        response.setNextDeadlineDate(request.getFirstInstallmentDueDate());
        response.setInstallments(installments.stream()
                .map(installmentMapper::toDto)
                .toList());
        response.setCreatedDate(LocalDateTime.now());

        return response;
    }

    /**
     * Register a payment for a specific installment
     * USER PREFERENCE: Updated for embedded installments
     */
    @Transactional
    public PaymentDto registerInstallmentPayment(String debtCaseId, String installmentId, BigDecimal amount, LocalDateTime paymentDate) {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Payment amount must be greater than zero");
        }

        LocalDate paymentLocalDate = paymentDate != null ?
            paymentDate.toLocalDate() : LocalDate.now();

        DebtCase debtCase = debtCaseRepository.findById(debtCaseId)
                .orElseThrow(() -> new RuntimeException("DebtCase not found with id: " + debtCaseId));

        // Find the installment within the embedded collection
        Installment installment = debtCase.getInstallments().stream()
                .filter(inst -> installmentId.equals(inst.getInstallmentId()))
                .findFirst()
                .orElseThrow(() -> new RuntimeException("Installment not found with id: " + installmentId));

        // Check if installment is already paid
        if (Boolean.TRUE.equals(installment.getPaid())) {
            throw new IllegalStateException("Installment is already marked as paid");
        }

        // Update installment as paid
        installment.setPaid(true);
        installment.setPaidDate(paymentDate != null ? paymentDate : LocalDateTime.now());
        installment.setPaidAmount(amount);
        installment.setLastModifiedDate(LocalDateTime.now());
        installment.setLastModifiedBy("system"); // TODO: get from security context

        // Create payment record linked to this installment
        Payment payment = new Payment();
        payment.setPaymentId(UUID.randomUUID().toString());
        payment.setAmount(amount.doubleValue()); // USER PREFERENCE: Convert BigDecimal (DTO) to Double (MongoDB)
        payment.setPaymentDate(paymentLocalDate);
        payment.setInstallmentId(installmentId); // Reference to installment within same DebtCase
        payment.setCreatedDate(LocalDateTime.now());
        payment.setLastModifiedDate(LocalDateTime.now());
        payment.setCreatedBy("system"); // TODO: get from security context
        payment.setLastModifiedBy("system"); // TODO: get from security context

        // Add payment to debt case embedded collection
        debtCase.getPayments().add(payment);

        // Save the debt case (saves all embedded documents)
        debtCaseRepository.save(debtCase);

        // Update debt case nextDeadlineDate to next unpaid installment
        updateNextDeadlineForInstallmentPlan(debtCase);

        // Check if all installments are paid and update case accordingly
        checkAndUpdateCaseCompletionStatus(debtCase);

        // USER PREFERENCE: Map payment to DTO and set debtCaseId since Payment is embedded
        PaymentDto paymentDto = paymentMapper.toDto(payment);
        paymentDto.setDebtCaseId(debtCaseId);

        return paymentDto;
    }

    /**
     * Update the nextDeadlineDate of a debt case to the next unpaid installment due date
     * USER PREFERENCE: Updated for embedded installments
     */
    private void updateNextDeadlineForInstallmentPlan(DebtCase debtCase) {
        if (Boolean.TRUE.equals(debtCase.getHasInstallmentPlan())) {
            // Find next unpaid installment within embedded collection
            Optional<Installment> nextUnpaidInstallment = debtCase.getInstallments().stream()
                    .filter(inst -> !Boolean.TRUE.equals(inst.getPaid()))
                    .min((inst1, inst2) -> inst1.getDueDate().compareTo(inst2.getDueDate()));

            if (nextUnpaidInstallment.isPresent()) {
                debtCase.setNextDeadlineDate(nextUnpaidInstallment.get().getDueDate());
            } else {
                // All installments are paid, set next deadline to current time
                debtCase.setNextDeadlineDate(LocalDateTime.now());
            }

            debtCaseRepository.save(debtCase);
        }
    }

    /**
     * Check if all installments are paid and update case status accordingly
     * USER PREFERENCE: Updated for embedded installments
     */
    private void checkAndUpdateCaseCompletionStatus(DebtCase debtCase) {
        if (Boolean.TRUE.equals(debtCase.getHasInstallmentPlan())) {
            // Find unpaid installments within embedded collection
            List<Installment> unpaidInstallments = debtCase.getInstallments().stream()
                    .filter(inst -> !Boolean.TRUE.equals(inst.getPaid()))
                    .toList();

            if (unpaidInstallments.isEmpty()) {
                // All installments are paid
                Double totalPaid = calculateTotalPaidAmount(debtCase);

                if (totalPaid.compareTo(debtCase.getOwedAmount()) >= 0 &&
                    debtCase.getCurrentState() != CaseState.COMPLETATA) {

                    debtCase.setNotes("Case automatically marked as COMPLETATA after all installments were paid");
                    debtCase.setCurrentState(CaseState.COMPLETATA);
                    LocalDateTime completionDate = LocalDateTime.now();
                    debtCase.setCurrentStateDate(completionDate);
                    debtCase.setPaid(true);
                    debtCase.setNextDeadlineDate(completionDate);

                    debtCaseRepository.save(debtCase);
                }
            }
        }
    }
}
