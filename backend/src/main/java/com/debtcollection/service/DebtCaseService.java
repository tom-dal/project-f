package com.debtcollection.service;

import com.debtcollection.dto.DebtCaseDto;
import com.debtcollection.dto.DebtCaseFilterRequest;
import com.debtcollection.dto.PaymentDto;
import com.debtcollection.dto.InstallmentPlanRequest;
import com.debtcollection.dto.InstallmentPlanResponse;
import com.debtcollection.dto.CasesSummaryDto;
import com.debtcollection.dto.InstallmentDto;
import com.debtcollection.mapper.DebtCaseMapper;
import com.debtcollection.mapper.PaymentMapper;
import com.debtcollection.mapper.InstallmentMapper;
import com.debtcollection.model.*;
import com.debtcollection.repository.DebtCaseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.LocalDate;
import java.util.List;
import java.util.ArrayList;
import java.util.Optional;
import java.util.UUID;
import java.util.Map;
import java.util.Comparator;

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
                debtCase.setNextDeadlineDate(currentStateDate.plusDays(30));
            }
        } else {
            // CUSTOM IMPLEMENTATION: For completed cases keep deadline null so they never appear in deadline filters
            debtCase.setNextDeadlineDate(null);
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
        
        // CUSTOM IMPLEMENTATION: Update expanded con tutti i campi modificabili
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
                    debtCase.setNextDeadlineDate(newStateDate.plusDays(30));
                }
            } else {
                debtCase.setNextDeadlineDate(null); // CUSTOM IMPLEMENTATION: null for completed
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
        // CUSTOM IMPLEMENTATION: Default sort fallback se il client non specifica sort
        if (pageable.getSort().isUnsorted()) {
            pageable = PageRequest.of(pageable.getPageNumber(), pageable.getPageSize(), Sort.by(Sort.Direction.ASC, "nextDeadlineDate"));
        }
        return debtCaseRepository.findByFilters(
            filterRequest.getDebtorName(),
            filterRequest.getState(),
            filterRequest.getStates(),
            filterRequest.getMinAmount(),
            filterRequest.getMaxAmount(),
            filterRequest.getHasInstallmentPlan(),
            filterRequest.getPaid(),
            filterRequest.getOngoingNegotiations(),
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
            debtCase.setCurrentState(CaseState.COMPLETATA);
            LocalDateTime completionDate = LocalDateTime.now();
            debtCase.setCurrentStateDate(completionDate);
            debtCase.setPaid(true);
            debtCase.setNextDeadlineDate(null); // CUSTOM IMPLEMENTATION: null for completed
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
                    debtCase.setNextDeadlineDate(null); // CUSTOM IMPLEMENTATION: null for completed
                    debtCaseRepository.save(debtCase);
                }
            }
        }
    }

    public CasesSummaryDto getCasesSummary() {
        LocalDate today = LocalDate.now();
        List<DebtCase> notCompleted = debtCaseRepository.findByCurrentStateNot(CaseState.COMPLETATA);
        long totalActiveCases = notCompleted.size();

        long overdue = notCompleted.stream()
            .filter(c -> c.getNextDeadlineDate() != null && c.getNextDeadlineDate().toLocalDate().isBefore(today))
            .count();

        long dueToday = notCompleted.stream()
            .filter(c -> c.getNextDeadlineDate() != null && c.getNextDeadlineDate().toLocalDate().isEqual(today))
            .count();

        long dueNext7Days = notCompleted.stream()
            .filter(c -> {
                if (c.getNextDeadlineDate() == null) return false;
                LocalDate d = c.getNextDeadlineDate().toLocalDate();
                return !d.isBefore(today) && !d.isAfter(today.plusDays(7));
            })
            .count();

        Map<String, Long> stateCounts = new java.util.LinkedHashMap<>();
        for (CaseState cs : CaseState.values()) {
            if (cs == CaseState.COMPLETATA) continue;
            stateCounts.put(cs.name(), 0L);
        }
        notCompleted.forEach(c -> stateCounts.computeIfPresent(c.getCurrentState().name(), (k,v) -> v+1));

        return new CasesSummaryDto(
            totalActiveCases,
            overdue,
            dueToday,
            dueNext7Days,
            stateCounts
        );
    }

    public record InstallmentInput(BigDecimal amount, LocalDateTime dueDate) {}

    @Transactional(readOnly = true)
    public DebtCaseDto getDebtCaseById(String id) {
        DebtCase debtCase = debtCaseRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("DebtCase not found with id: " + id));
        return debtCaseMapper.toDto(debtCase);
    }

    @Transactional
    public DebtCaseDto updateNextDeadline(String id, LocalDateTime nextDeadlineDate) {
        if (nextDeadlineDate == null) throw new IllegalArgumentException("nextDeadlineDate cannot be null");
        DebtCase debtCase = debtCaseRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("DebtCase not found with id: " + id));
        if (debtCase.getCurrentState() != CaseState.COMPLETATA && nextDeadlineDate.isBefore(LocalDateTime.now())) {
            throw new IllegalArgumentException("La nuova scadenza non può essere nel passato");
        }
        if (Boolean.TRUE.equals(debtCase.getHasInstallmentPlan())) {
            // Validate coherence with earliest unpaid installment
            debtCase.getInstallments().stream()
                    .filter(i -> !Boolean.TRUE.equals(i.getPaid()))
                    .min(Comparator.comparing(Installment::getDueDate))
                    .ifPresent(firstUnpaid -> {
                        if (nextDeadlineDate.isAfter(firstUnpaid.getDueDate())) {
                            throw new IllegalArgumentException("La scadenza non può essere successiva alla prima rata non pagata");
                        }
                    });
        }
        debtCase.setNextDeadlineDate(nextDeadlineDate);
        debtCaseRepository.save(debtCase);
        return debtCaseMapper.toDto(debtCase);
    }

    @Transactional
    public InstallmentDto updateSingleInstallment(String debtCaseId, String installmentId, BigDecimal amount, LocalDateTime dueDate) {
        if (amount == null && dueDate == null) {
            throw new IllegalArgumentException("Nessun campo da aggiornare");
        }
        DebtCase debtCase = debtCaseRepository.findById(debtCaseId)
                .orElseThrow(() -> new IllegalArgumentException("DebtCase not found with id: " + debtCaseId));
        if (!Boolean.TRUE.equals(debtCase.getHasInstallmentPlan())) {
            throw new IllegalStateException("La pratica non ha un piano rate");
        }
        Installment installment = debtCase.getInstallments().stream()
                .filter(i -> installmentId.equals(i.getInstallmentId()))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Installment not found with id: " + installmentId));
        if (Boolean.TRUE.equals(installment.getPaid())) {
            throw new IllegalStateException("Impossibile modificare una rata già pagata");
        }
        if (amount != null) {
            if (amount.compareTo(BigDecimal.ZERO) <= 0) throw new IllegalArgumentException("Amount must be > 0");
            installment.setAmount(amount);
        }
        if (dueDate != null) {
            if (dueDate.isBefore(LocalDateTime.now())) {
                throw new IllegalArgumentException("La data di scadenza non può essere nel passato");
            }
            // Validate ordering constraints
            // previous installment (by date excluding itself)
            debtCase.getInstallments().stream()
                    .filter(i -> !i.getInstallmentId().equals(installmentId))
                    .filter(i -> !Boolean.TRUE.equals(i.getPaid()))
                    .filter(i -> i.getDueDate().isBefore(installment.getDueDate())) // existing ordering baseline
                    .min((a,b) -> b.getDueDate().compareTo(a.getDueDate())); // last before
            // We'll compute neighbors after tentative update
            LocalDateTime oldDue = installment.getDueDate();
            installment.setDueDate(dueDate);
            validateInstallmentOrdering(debtCase, allowPaidPastDates(true));
            installment.setLastModifiedDate(LocalDateTime.now());
        }
        reorderInstallmentNumbers(debtCase);
        // Recompute next deadline
        updateNextDeadlineForInstallmentPlan(debtCase);
        debtCaseRepository.save(debtCase);
        InstallmentDto dto = installmentMapper.toDto(installment);
        dto.setDebtCaseId(debtCaseId);
        return dto;
    }

    @Transactional
    public InstallmentPlanResponse replaceInstallmentPlan(String debtCaseId, List<InstallmentInput> installmentsInput) {
        if (installmentsInput == null || installmentsInput.isEmpty()) {
            throw new IllegalArgumentException("Lista rate vuota");
        }
        DebtCase debtCase = debtCaseRepository.findById(debtCaseId)
                .orElseThrow(() -> new IllegalArgumentException("DebtCase not found with id: " + debtCaseId));
        // Block replacement if any existing installment paid
        boolean anyPaid = debtCase.getInstallments().stream().anyMatch(i -> Boolean.TRUE.equals(i.getPaid()));
        if (anyPaid) {
            throw new IllegalStateException("Impossibile sostituire il piano: esistono rate già pagate");
        }
        // Validate input ordering and dates
        List<InstallmentInput> sorted = installmentsInput.stream()
                .sorted(Comparator.comparing(InstallmentInput::dueDate))
                .toList();
        for (int i = 0; i < sorted.size(); i++) {
            InstallmentInput in = sorted.get(i);
            if (in.amount() == null || in.amount().compareTo(BigDecimal.ZERO) <= 0) {
                throw new IllegalArgumentException("Importo rata non valido (index=" + i + ")");
            }
            if (in.dueDate() == null) throw new IllegalArgumentException("Data rata mancante (index=" + i + ")");
            if (in.dueDate().isBefore(LocalDateTime.now())) {
                throw new IllegalArgumentException("La rata " + (i+1) + " ha una data nel passato");
            }
            if (i > 0 && !in.dueDate().isAfter(sorted.get(i-1).dueDate())) {
                throw new IllegalArgumentException("Le date devono essere strettamente crescenti");
            }
        }
        debtCase.getInstallments().clear();
        int number = 1;
        for (InstallmentInput in : sorted) {
            Installment inst = new Installment();
            inst.setInstallmentId(UUID.randomUUID().toString());
            inst.setInstallmentNumber(number++);
            inst.setAmount(in.amount());
            inst.setDueDate(in.dueDate());
            inst.setPaid(false);
            inst.setCreatedDate(LocalDateTime.now());
            inst.setLastModifiedDate(LocalDateTime.now());
            inst.setCreatedBy("system"); // TODO security context
            inst.setLastModifiedBy("system");
            debtCase.getInstallments().add(inst);
        }
        debtCase.setHasInstallmentPlan(true);
        debtCase.setNextDeadlineDate(sorted.get(0).dueDate());
        debtCaseRepository.save(debtCase);
        InstallmentPlanResponse response = new InstallmentPlanResponse();
        response.setDebtCaseId(debtCaseId);
        response.setNumberOfInstallments(debtCase.getInstallments().size());
        response.setNextDeadlineDate(debtCase.getNextDeadlineDate());
        response.setInstallments(debtCase.getInstallments().stream().map(installmentMapper::toDto).toList());
        response.setCreatedDate(LocalDateTime.now());
        return response;
    }

    @Transactional
    public DebtCaseDto deleteInstallmentPlan(String debtCaseId) {
        DebtCase debtCase = debtCaseRepository.findById(debtCaseId)
                .orElseThrow(() -> new IllegalArgumentException("DebtCase not found with id: " + debtCaseId));
        if (!Boolean.TRUE.equals(debtCase.getHasInstallmentPlan())) {
            throw new IllegalStateException("La pratica non ha un piano rate");
        }
        boolean anyPaid = debtCase.getInstallments().stream().anyMatch(i -> Boolean.TRUE.equals(i.getPaid()));
        if (anyPaid) {
            throw new IllegalStateException("Impossibile eliminare il piano: esistono rate già pagate");
        }
        debtCase.getInstallments().clear();
        debtCase.setHasInstallmentPlan(false);
        // Recalculate next deadline based on state
        if (debtCase.getCurrentState() != CaseState.COMPLETATA) {
            LocalDate next = stateTransitionService.calculateNextDeadline(debtCase.getCurrentState(), debtCase.getCurrentStateDate());
            if (next != null) {
                debtCase.setNextDeadlineDate(next.atStartOfDay());
            } else {
                debtCase.setNextDeadlineDate(null);
            }
        } else {
            debtCase.setNextDeadlineDate(null);
        }
        debtCaseRepository.save(debtCase);
        return debtCaseMapper.toDto(debtCase);
    }

    private void reorderInstallmentNumbers(DebtCase debtCase) {
        debtCase.getInstallments().sort(Comparator.comparing(Installment::getDueDate));
        int idx = 1;
        for (Installment inst : debtCase.getInstallments()) {
            inst.setInstallmentNumber(idx++);
        }
    }

    private void validateInstallmentOrdering(DebtCase debtCase, boolean allowPaidPastDates) {
        List<Installment> list = debtCase.getInstallments().stream()
                .sorted(Comparator.comparing(Installment::getDueDate))
                .toList();
        LocalDateTime prev = null;
        for (Installment inst : list) {
            if (Boolean.TRUE.equals(inst.getPaid())) {
                if (!allowPaidPastDates && inst.getDueDate().isBefore(LocalDateTime.now())) {
                    throw new IllegalArgumentException("Rata pagata con data passata non consentita");
                }
            } else {
                if (inst.getDueDate().isBefore(LocalDateTime.now())) {
                    throw new IllegalArgumentException("Le rate non pagate non possono avere scadenza nel passato");
                }
            }
            if (prev != null && !inst.getDueDate().isAfter(prev)) {
                throw new IllegalArgumentException("Le date delle rate devono essere strettamente crescenti");
            }
            prev = inst.getDueDate();
        }
    }

    private boolean allowPaidPastDates(boolean value) { return value; }

    // --- Payments Management (reintroduced) ---
    @Transactional(readOnly = true)
    public List<PaymentDto> listPayments(String debtCaseId) {
        DebtCase debtCase = debtCaseRepository.findById(debtCaseId)
                .orElseThrow(() -> new IllegalArgumentException("DebtCase not found with id: " + debtCaseId));
        return debtCase.getPayments().stream()
                .sorted(Comparator.comparing(Payment::getPaymentDate).thenComparing(Payment::getCreatedDate))
                .map(p -> {
                    PaymentDto dto = paymentMapper.toDto(p);
                    dto.setDebtCaseId(debtCaseId);
                    return dto;
                })
                .toList();
    }

    @Transactional
    public PaymentDto updatePayment(String debtCaseId, String paymentId, BigDecimal amount, LocalDate paymentDate) {
        DebtCase debtCase = debtCaseRepository.findById(debtCaseId)
                .orElseThrow(() -> new IllegalArgumentException("DebtCase not found with id: " + debtCaseId));
        Payment payment = debtCase.getPayments().stream()
                .filter(p -> paymentId.equals(p.getPaymentId()))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Payment not found with id: " + paymentId));
        if (amount != null) {
            if (amount.compareTo(BigDecimal.ZERO) <= 0) throw new IllegalArgumentException("Payment amount must be > 0");
            payment.setAmount(amount.doubleValue());
        }
        if (paymentDate != null) {
            payment.setPaymentDate(paymentDate);
        }
        payment.setLastModifiedDate(LocalDateTime.now());
        payment.setLastModifiedBy("system"); // CUSTOM IMPLEMENTATION: placeholder user

        // Se pagamento legato a rata aggiorna i dati rata
        if (payment.getInstallmentId() != null) {
            debtCase.getInstallments().stream()
                    .filter(i -> payment.getInstallmentId().equals(i.getInstallmentId()))
                    .findFirst()
                    .ifPresent(inst -> {
                        if (amount != null) inst.setPaidAmount(amount);
                        if (paymentDate != null) inst.setPaidDate(paymentDate.atStartOfDay());
                        inst.setLastModifiedDate(LocalDateTime.now());
                    });
        }
        // Ricalcolo flag paid (e completamento se supera importo)
        Double totalPaid = calculateTotalPaidAmount(debtCase);
        boolean fullyPaid = totalPaid.compareTo(debtCase.getOwedAmount()) >= 0;
        debtCase.setPaid(fullyPaid);
        if (fullyPaid && debtCase.getCurrentState() != CaseState.COMPLETATA) {
            debtCase.setNotes("Case automatically marked as COMPLETATA after payment update");
            debtCase.setCurrentState(CaseState.COMPLETATA);
            debtCase.setCurrentStateDate(LocalDateTime.now());
            debtCase.setNextDeadlineDate(null);
        }
        debtCaseRepository.save(debtCase);
        PaymentDto dto = paymentMapper.toDto(payment);
        dto.setDebtCaseId(debtCaseId);
        return dto;
    }

    @Transactional
    public void deletePayment(String debtCaseId, String paymentId) {
        DebtCase debtCase = debtCaseRepository.findById(debtCaseId)
                .orElseThrow(() -> new IllegalArgumentException("DebtCase not found with id: " + debtCaseId));
        Payment target = null;
        for (Payment p : debtCase.getPayments()) {
            if (paymentId.equals(p.getPaymentId())) { target = p; break; }
        }
        if (target == null) throw new IllegalArgumentException("Payment not found with id: " + paymentId);
        String targetInstallmentId = target.getInstallmentId(); // make effectively final for lambda
        debtCase.getPayments().remove(target);
        if (targetInstallmentId != null) {
            final String instId = targetInstallmentId;
            debtCase.getInstallments().stream()
                    .filter(i -> instId.equals(i.getInstallmentId()))
                    .findFirst()
                    .ifPresent(inst -> {
                        inst.setPaid(false);
                        inst.setPaidAmount(null);
                        inst.setPaidDate(null);
                        inst.setLastModifiedDate(LocalDateTime.now());
                    });
        }
        Double totalPaid = calculateTotalPaidAmount(debtCase);
        debtCase.setPaid(totalPaid.compareTo(debtCase.getOwedAmount()) >= 0);
        debtCaseRepository.save(debtCase);
    }
}

