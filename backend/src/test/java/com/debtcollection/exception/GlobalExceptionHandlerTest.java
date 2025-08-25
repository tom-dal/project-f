package com.debtcollection.exception;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.BeanPropertyBindingResult;
import org.springframework.validation.BindException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.core.MethodParameter;

import jakarta.validation.Valid;

import java.lang.reflect.Method;
import java.time.LocalDateTime;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests for GlobalExceptionHandler to cover all branches.
 */
class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    // Dummy method to build a MethodParameter for MethodArgumentNotValidException
    @SuppressWarnings("unused")
    private void dummy(@Valid String value) { }

    @Test
    @DisplayName("BusinessValidationException con tutti i campi opzionali")
    void businessValidation_full() {
        BusinessValidationException ex = new BusinessValidationException(
                "ERR_CODE", "Messaggio", "fieldX", "curr", "expected");
        ResponseEntity<Map<String, Object>> resp = handler.handleBusinessValidationException(ex);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        Map<String, Object> body = resp.getBody();
        assertThat(body).isNotNull();
        assertThat(body.get("message")).isEqualTo("Messaggio");
        assertThat(body.get("error")).isEqualTo("BusinessValidationException");
        assertThat(body.get("errorCode")).isEqualTo("ERR_CODE");
        assertThat(body).containsKeys("field", "currentValue", "expectedValue", "timestamp");
    }

    @Test
    @DisplayName("BusinessValidationException senza campi opzionali")
    void businessValidation_minimal() {
        BusinessValidationException ex = new BusinessValidationException(
                "ERR_SIMPLE", "Simple message");
        ResponseEntity<Map<String, Object>> resp = handler.handleBusinessValidationException(ex);
        Map<String, Object> body = resp.getBody();
        assertThat(body).isNotNull();
        assertThat(body.containsKey("field")).isFalse();
        assertThat(body.containsKey("currentValue")).isFalse();
        assertThat(body.containsKey("expectedValue")).isFalse();
    }

    @Test
    @DisplayName("BindException restituisce primo messaggio di errore")
    void bindException() {
        Object target = new Object();
        BindException bindEx = new BindException(target, "obj");
        bindEx.addError(new FieldError("obj", "fieldA", "MsgA"));
        ResponseEntity<Map<String, Object>> resp = handler.handleValidationExceptions(bindEx);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).isNotNull();
        assertThat(resp.getBody().get("message")).isEqualTo("MsgA");
        assertThat(resp.getBody().get("error")).isEqualTo("ValidationException");
    }

    @Test
    @DisplayName("MethodArgumentNotValidException restituisce primo messaggio di errore")
    void methodArgumentNotValidException() throws Exception {
        Method m = this.getClass().getDeclaredMethod("dummy", String.class);
        MethodParameter param = new MethodParameter(m, 0);
        BeanPropertyBindingResult bindingResult = new BeanPropertyBindingResult("val", "dummy");
        bindingResult.addError(new FieldError("dummy", "value", "Invalid value"));
        MethodArgumentNotValidException manve = new MethodArgumentNotValidException(param, bindingResult);
        ResponseEntity<Map<String, Object>> resp = handler.handleValidationExceptions(manve);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).isNotNull();
        assertThat(resp.getBody().get("message")).isEqualTo("Invalid value");
    }

    @Test
    @DisplayName("Generic Exception -> 500 con messaggio")
    void genericException() {
        Exception ex = new IllegalStateException("Boom");
        ResponseEntity<Map<String, Object>> resp = handler.handleGenericException(ex);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(resp.getBody()).isNotNull();
        assertThat(resp.getBody().get("message")).isEqualTo("Boom");
        assertThat(resp.getBody().get("error")).isEqualTo("IllegalStateException");
        assertThat(resp.getBody().get("timestamp")).isInstanceOf(LocalDateTime.class);
    }
}

