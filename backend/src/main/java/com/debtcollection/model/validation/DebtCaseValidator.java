package com.debtcollection.model.validation;

import com.debtcollection.model.DebtCase;
import com.debtcollection.model.Installment;
import com.debtcollection.exception.BusinessValidationException;
import com.debtcollection.exception.ValidationErrorCodes;
import com.debtcollection.model.Payment;
import org.springframework.data.mongodb.core.mapping.event.AbstractMongoEventListener;
import org.springframework.data.mongodb.core.mapping.event.BeforeConvertEvent;
import org.springframework.stereotype.Component;
import java.math.BigDecimal;
import java.util.Objects;

/**
 * MongoDB Event Listener per DebtCase
 * Viene eseguito automaticamente prima di ogni operazione di salvataggio
 */
@Component
public class DebtCaseValidator extends AbstractMongoEventListener<DebtCase> {

    /**
     * MongoDB event listener - triggered automatically before save/update
     */
    @Override
    public void onBeforeConvert(BeforeConvertEvent<DebtCase> event) {
        DebtCase debtCase = event.getSource();
        validateBeforeSave(debtCase);
    }

    /**
     * Metodo di validazione principale
     */
    public void validateBeforeSave(DebtCase debtCase) {
        validateDebtorName(debtCase);
        validateOwedAmount(debtCase);
        validateInstallmentPlanConsistency(debtCase);
        validateInstallmentPaymentConsistency(debtCase);
        validateDebtCasePaidConsistency(debtCase);
        validateBusinessRules(debtCase);
    }

    private void validateDebtorName(DebtCase debtCase) {
        // Database handles nullable check, we only validate business rules
        if (debtCase.getDebtorName() != null) {
            if (debtCase.getDebtorName().length() < 2) {
                throw new BusinessValidationException(
                    ValidationErrorCodes.DEBTOR_NAME_TOO_SHORT,
                    "Debtor name must be at least 2 characters long",
                    "debtorName",
                    debtCase.getDebtorName().length(),
                    2
                );
            }
            if (debtCase.getDebtorName().length() > 255) {
                throw new BusinessValidationException(
                    ValidationErrorCodes.DEBTOR_NAME_TOO_LONG,
                    "Debtor name cannot exceed 255 characters",
                    "debtorName",
                    debtCase.getDebtorName().length(),
                    255
                );
            }
        }
    }

    private void validateOwedAmount(DebtCase debtCase) {
        // Database handles nullable check, we only validate business rules
        if (debtCase.getOwedAmount() != null) {
            if (debtCase.getOwedAmount() <= 0) {
                throw new BusinessValidationException(
                    ValidationErrorCodes.AMOUNT_NOT_POSITIVE,
                    "Owed amount must be greater than zero",
                    "owedAmount",
                    debtCase.getOwedAmount(),
                    "positive value"
                );
            }
            // La validazione della precisione decimale sarà gestita a livello di DTO/API
        }
    }

    private void validateInstallmentPlanConsistency(DebtCase debtCase) {
        // CUSTOM IMPLEMENTATION: Validazione coerenza piano di rateizzazione
        // Forza il caricamento degli installments per garantire validazione completa
        
        if (debtCase.getInstallments() == null || debtCase.getInstallments().isEmpty()) {
            if (Boolean.TRUE.equals(debtCase.getHasInstallmentPlan())) {
                throw new BusinessValidationException(
                    ValidationErrorCodes.INSTALLMENT_PLAN_FLAG_MISMATCH,
                    "Debt case marked as having installment plan but no installments found",
                    "hasInstallmentPlan"
                );
            }
        } else {
            if (Boolean.FALSE.equals(debtCase.getHasInstallmentPlan())) {
                throw new BusinessValidationException(
                    ValidationErrorCodes.INSTALLMENT_PLAN_FLAG_MISMATCH,
                    "Debt case marked as not having installment plan but installments found",
                    "hasInstallmentPlan"
                );
            }
        }
    }

    private void validateInstallmentPaymentConsistency(DebtCase debtCase) {
        // CUSTOM IMPLEMENTATION: Validazione che installments pagati abbiano payment corrispondente
        // Forza il caricamento degli installments per garantire validazione completa
        
        if (debtCase.getInstallments() != null && !debtCase.getInstallments().isEmpty()) {
            for (int i = 0; i < debtCase.getInstallments().size(); i++) {
                Installment installment = debtCase.getInstallments().get(i);

                if (Boolean.TRUE.equals(installment.getPaid())) {
                    if (installment.getPaid() && debtCase.getPayments().stream().map(Payment::getInstallmentId).noneMatch(id -> installment.getInstallmentId().equals(id))) {
                        throw new BusinessValidationException(
                            ValidationErrorCodes.INSTALLMENT_PAID_WITHOUT_PAYMENT,
                            String.format("Installment #%d is marked as paid but has no paid amount",
                                installment.getInstallmentNumber() != null ? installment.getInstallmentNumber() : i + 1),
                            "installments[" + i + "].paid",
                            true,
                            "requires paid amount"
                        );
                    }
                }
            }
        }
    }

    private void validateDebtCasePaidConsistency(DebtCase debtCase) {
        // CUSTOM IMPLEMENTATION: Validazione che debt case pagato abbia payments sufficienti
        // Forza il caricamento dei payments per garantire validazione completa
        
        if (Boolean.TRUE.equals(debtCase.getPaid())) {
            if (debtCase.getPayments() == null || debtCase.getPayments().isEmpty()) {
                throw new BusinessValidationException(
                    ValidationErrorCodes.DEBT_CASE_PAID_WITHOUT_PAYMENTS,
                    "Debt case marked as paid but has no payments",
                    "paid"
                );
            }
            
            // Calcola la somma dei pagamenti e confronta con l'importo dovuto
            Double totalPayments = debtCase.getPayments().stream()
                .map(payment -> payment.getAmount())
                .reduce(0.0, Double::sum);

            Double owedAmount = debtCase.getOwedAmount();

            if (totalPayments.compareTo(owedAmount) < 0) {
                throw new BusinessValidationException(
                    ValidationErrorCodes.DEBT_CASE_PAID_INSUFFICIENT_PAYMENTS,
                    String.format("Debt case marked as paid but total payments (%.2f) is less than owed amount (%.2f)",
                        totalPayments.doubleValue(), debtCase.getOwedAmount()),
                    "paid",
                    totalPayments,
                    owedAmount
                );
            }
        }
    }

    /**
     * CUSTOM IMPLEMENTATION: Business rules validation
     * Solo validazioni che non possono essere gestite dal database
     */
    private void validateBusinessRules(DebtCase debtCase) {
        // Validazione date: solo se entrambe presenti, confronta la logica
        if (Boolean.TRUE.equals(debtCase.getOngoingNegotiations()) 
            && debtCase.getNextDeadlineDate() != null
            && debtCase.getCurrentStateDate() != null
            && debtCase.getNextDeadlineDate().isBefore(debtCase.getCurrentStateDate())) {
            throw new IllegalArgumentException(
                "Next deadline date cannot be before current state date when ongoing negotiations are active"
            );
        }

        // Validazione business logic su stati
        if (debtCase.getCurrentState() != null 
            && "CLOSED".equals(debtCase.getCurrentState().name())
            && Boolean.TRUE.equals(debtCase.getOngoingNegotiations())) {
            throw new BusinessValidationException(
                ValidationErrorCodes.CLOSED_CASE_WITH_NEGOTIATIONS,
                "Cannot have ongoing negotiations when case is closed",
                "ongoingNegotiations"
            );
        }

        // Validazione installments - forza caricamento se necessario
        if (debtCase.getInstallments() != null && !debtCase.getInstallments().isEmpty()) {
            validateInstallments(debtCase);
        }
    }

    private void validateInstallments(DebtCase debtCase) {
        // La somma delle installments non deve superare l'importo dovuto
        BigDecimal totalInstallments = debtCase.getInstallments().stream()
            .map(installment -> installment.getAmount())
            .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal owedAmountBD = BigDecimal.valueOf(debtCase.getOwedAmount());

        if (totalInstallments.compareTo(owedAmountBD) > 0) {
            throw new BusinessValidationException(
                ValidationErrorCodes.INSTALLMENTS_EXCEED_OWED_AMOUNT,
                String.format("Total installments amount (%.2f) cannot exceed owed amount (%.2f)",
                    totalInstallments.doubleValue(), debtCase.getOwedAmount()),
                "installments",
                totalInstallments,
                owedAmountBD
            );
        }
        
        // Validazione aggiuntiva: nessun installment può avere amount nullo o negativo
        for (int i = 0; i < debtCase.getInstallments().size(); i++) {
            BigDecimal installmentAmount = debtCase.getInstallments().get(i).getAmount();
            if (installmentAmount == null || installmentAmount.compareTo(BigDecimal.ZERO) <= 0) {
                throw new BusinessValidationException(
                    ValidationErrorCodes.INSTALLMENT_AMOUNT_INVALID,
                    String.format("Installment #%d must have a positive amount", i + 1),
                    "installments[" + i + "].amount",
                    installmentAmount,
                    "positive value"
                );
            }
        }
    }
}
