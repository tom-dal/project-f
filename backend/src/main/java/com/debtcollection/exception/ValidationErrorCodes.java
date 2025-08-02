package com.debtcollection.exception;

/**
 * CUSTOM IMPLEMENTATION: Codici di errore per validazioni business
 * Utilizzati dal frontend per gestire errori specifici
 */
public final class ValidationErrorCodes {
    
    // Debtor validation errors
    public static final String DEBTOR_NAME_TOO_SHORT = "DEBTOR_NAME_TOO_SHORT";
    public static final String DEBTOR_NAME_TOO_LONG = "DEBTOR_NAME_TOO_LONG";
    
    // Amount validation errors
    public static final String AMOUNT_NOT_POSITIVE = "AMOUNT_NOT_POSITIVE";
    public static final String AMOUNT_INVALID_SCALE = "AMOUNT_INVALID_SCALE";
    
    // Installment plan validation errors
    public static final String INSTALLMENT_PLAN_FLAG_MISMATCH = "INSTALLMENT_PLAN_FLAG_MISMATCH";
    public static final String INSTALLMENTS_EXCEED_OWED_AMOUNT = "INSTALLMENTS_EXCEED_OWED_AMOUNT";
    public static final String INSTALLMENT_AMOUNT_INVALID = "INSTALLMENT_AMOUNT_INVALID";
    
    // Payment validation errors
    public static final String INSTALLMENT_PAID_WITHOUT_PAYMENT = "INSTALLMENT_PAID_WITHOUT_PAYMENT";
    public static final String DEBT_CASE_PAID_WITHOUT_PAYMENTS = "DEBT_CASE_PAID_WITHOUT_PAYMENTS";
    public static final String DEBT_CASE_PAID_INSUFFICIENT_PAYMENTS = "DEBT_CASE_PAID_INSUFFICIENT_PAYMENTS";
    
    // Business rules validation errors
    public static final String CLOSED_CASE_WITH_NEGOTIATIONS = "CLOSED_CASE_WITH_NEGOTIATIONS";
    public static final String INVALID_DEADLINE_DATE = "INVALID_DEADLINE_DATE";
    
    private ValidationErrorCodes() {
        // Utility class - no instantiation
    }
}
