package com.debtcollection.exception;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.validation.BindException;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * CUSTOM IMPLEMENTATION: Global exception handler per API
 * Gestisce le eccezioni custom per il frontend
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    /**
     * Handle validation errors (Bean Validation @Valid)
     * Restituisce HTTP 400 e messaggio coerente con convenzioni API
     */
    @ExceptionHandler({MethodArgumentNotValidException.class, BindException.class})
    public ResponseEntity<Map<String, Object>> handleValidationExceptions(Exception ex) {
        String message = "Validation failed";
        if (ex instanceof MethodArgumentNotValidException manve) {
            if (!manve.getBindingResult().getAllErrors().isEmpty()) {
                message = manve.getBindingResult().getAllErrors().get(0).getDefaultMessage();
            }
        } else if (ex instanceof BindException be) {
            if (!be.getBindingResult().getAllErrors().isEmpty()) {
                message = be.getBindingResult().getAllErrors().get(0).getDefaultMessage();
            }
        }
        Map<String, Object> errorResponse = new HashMap<>();
        errorResponse.put("message", message);
        errorResponse.put("error", "ValidationException");
        errorResponse.put("timestamp", LocalDateTime.now());
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);
    }

    @ExceptionHandler(BusinessValidationException.class)
    public ResponseEntity<Map<String, Object>> handleBusinessValidationException(
            BusinessValidationException ex) {
        
        Map<String, Object> errorResponse = new HashMap<>();
        errorResponse.put("message", ex.getMessage());
        errorResponse.put("error", "BusinessValidationException");
        errorResponse.put("timestamp", LocalDateTime.now());
        errorResponse.put("errorCode", ex.getErrorCode());
        
        if (ex.getField() != null) {
            errorResponse.put("field", ex.getField());
        }
        
        if (ex.getCurrentValue() != null) {
            errorResponse.put("currentValue", ex.getCurrentValue());
        }
        
        if (ex.getExpectedValue() != null) {
            errorResponse.put("expectedValue", ex.getExpectedValue());
        }
        
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);
    }
    
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGenericException(Exception ex) {
        Map<String, Object> errorResponse = new HashMap<>();
        errorResponse.put("message", ex.getMessage());
        errorResponse.put("error", ex.getClass().getSimpleName());
        errorResponse.put("timestamp", LocalDateTime.now());
        
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<Map<String,Object>> handleAccessDenied(AccessDeniedException ex) {
        // Garantisce risposta 403 coerente anche per eccezioni lanciate da method security
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
                .body(Map.of(
                        "message", ex.getMessage() != null ? ex.getMessage() : "Access Denied",
                        "error", "AccessDeniedException",
                        "timestamp", OffsetDateTime.now().toString()
                ));
    }
}
