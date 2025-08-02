package com.debtcollection.exception;

/**
 * CUSTOM IMPLEMENTATION: Eccezione per errori di validazione business
 * Contiene informazioni strutturate per il frontend
 */
public class BusinessValidationException extends RuntimeException {
    
    private final String errorCode;
    private final String field;
    private final Object currentValue;
    private final Object expectedValue;
    
    public BusinessValidationException(String errorCode, String message) {
        super(message);
        this.errorCode = errorCode;
        this.field = null;
        this.currentValue = null;
        this.expectedValue = null;
    }
    
    public BusinessValidationException(String errorCode, String message, String field) {
        super(message);
        this.errorCode = errorCode;
        this.field = field;
        this.currentValue = null;
        this.expectedValue = null;
    }
    
    public BusinessValidationException(String errorCode, String message, String field, 
                                     Object currentValue, Object expectedValue) {
        super(message);
        this.errorCode = errorCode;
        this.field = field;
        this.currentValue = currentValue;
        this.expectedValue = expectedValue;
    }
    
    public String getErrorCode() {
        return errorCode;
    }
    
    public String getField() {
        return field;
    }
    
    public Object getCurrentValue() {
        return currentValue;
    }
    
    public Object getExpectedValue() {
        return expectedValue;
    }
}
