package com.debtcollection.service;

import com.debtcollection.dto.PaymentDto;
import com.debtcollection.mapper.DebtCaseMapper;
import com.debtcollection.mapper.PaymentMapper;
import com.debtcollection.model.CaseState;
import com.debtcollection.model.DebtCase;
import com.debtcollection.model.Payment;
import com.debtcollection.repository.DebtCaseRepository;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.LocalDate;
import java.util.Optional;
import java.util.ArrayList;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DebtCaseServiceTest {

    @Mock
    private DebtCaseRepository debtCaseRepository;
    
    @Mock
    private StateTransitionService stateTransitionService;
    
    @Mock
    private DebtCaseMapper debtCaseMapper;
    
    @Mock
    private PaymentMapper paymentMapper;

    @InjectMocks
    private DebtCaseService debtCaseService;

    private DebtCase debtCase;
    private Payment payment;
    private PaymentDto paymentDto;

    @BeforeEach
    void setUp() {
        debtCase = new DebtCase();
        debtCase.setId("507f1f77bcf86cd799439011"); // USER PREFERENCE: MongoDB ObjectId as String
        debtCase.setDebtorName("Mario Rossi");
        debtCase.setOwedAmount(1000.00); // USER PREFERENCE: Convert BigDecimal to Double for MongoDB

        // CUSTOM IMPLEMENTATION: Usa i nuovi campi diretti
        debtCase.setCurrentState(CaseState.MESSA_IN_MORA_DA_FARE);
        debtCase.setCurrentStateDate(LocalDateTime.now());
        debtCase.setHasInstallmentPlan(false);
        debtCase.setPaid(false);
        debtCase.setOngoingNegotiations(false);
        
        // Initialize payments collection
        debtCase.setPayments(new ArrayList<>());

        // USER PREFERENCE: Payment is now embedded document - no setId method
        payment = new Payment();
        payment.setPaymentId("payment-123"); // Internal embedded document ID
        payment.setAmount(500.00); // USER PREFERENCE: Convert BigDecimal to Double for MongoDB
        payment.setPaymentDate(LocalDate.now());

        paymentDto = new PaymentDto();
        paymentDto.setId("payment-123"); // USER PREFERENCE: String ID for MongoDB
        paymentDto.setAmount(new BigDecimal("500.00"));
        paymentDto.setPaymentDate(LocalDate.now());
        paymentDto.setDebtCaseId("507f1f77bcf86cd799439011"); // USER PREFERENCE: String ID for MongoDB
    }

    @Test
    void registerPayment_ShouldCreatePaymentSuccessfully() {
        // Given
        when(debtCaseRepository.findById("507f1f77bcf86cd799439011")).thenReturn(Optional.of(debtCase));
        when(debtCaseRepository.save(any(DebtCase.class))).thenReturn(debtCase);
        when(paymentMapper.toDto(any(Payment.class))).thenReturn(paymentDto);

        // When
        PaymentDto result = debtCaseService.registerPayment("507f1f77bcf86cd799439011", new BigDecimal("500.00"), LocalDateTime.now());

        // Then
        assertNotNull(result);
        assertEquals(new BigDecimal("500.00"), result.getAmount());
        verify(debtCaseRepository).save(any(DebtCase.class));
        assertEquals(1, debtCase.getPayments().size()); // Should have added one payment
        assertEquals(CaseState.MESSA_IN_MORA_DA_FARE, debtCase.getCurrentState()); // Should not change state for partial payment
    }

    @Test
    void registerPayment_ShouldMarkCaseAsCompleted_WhenFullAmountPaid() {
        // Given
        when(debtCaseRepository.findById("507f1f77bcf86cd799439011")).thenReturn(Optional.of(debtCase));
        when(debtCaseRepository.save(any(DebtCase.class))).thenReturn(debtCase);
        when(paymentMapper.toDto(any(Payment.class))).thenReturn(paymentDto);

        // When
        PaymentDto result = debtCaseService.registerPayment("507f1f77bcf86cd799439011", new BigDecimal("1000.00"), LocalDateTime.now());

        // Then
        assertNotNull(result);
        verify(debtCaseRepository).save(any(DebtCase.class));
        assertEquals(CaseState.COMPLETATA, debtCase.getCurrentState()); // Should update case state to COMPLETATA
        assertEquals(1, debtCase.getPayments().size()); // Should have added one payment
    }

    @Test
    void registerPayment_ShouldThrowException_WhenInvalidAmount() {
        // When & Then
        assertThrows(IllegalArgumentException.class, 
            () -> debtCaseService.registerPayment("507f1f77bcf86cd799439011", BigDecimal.ZERO, LocalDateTime.now()));

        assertThrows(IllegalArgumentException.class, 
            () -> debtCaseService.registerPayment("507f1f77bcf86cd799439011", new BigDecimal("-100"), LocalDateTime.now()));
    }

    @Test
    void registerPayment_ShouldThrowException_WhenDebtCaseNotFound() {
        // Given
        when(debtCaseRepository.findById("999999999999999999999999")).thenReturn(Optional.empty());

        // When & Then
        assertThrows(RuntimeException.class, 
            () -> debtCaseService.registerPayment("999999999999999999999999", new BigDecimal("100.00"), LocalDateTime.now()));
    }

    @Test
    void calculateTotalPaidAmount_ShouldReturnCorrectSum() {
        // Given
        Payment payment1 = new Payment();
        payment1.setAmount(300.00); // USER PREFERENCE: Convert BigDecimal to Double for MongoDB
        payment1.setPaymentDate(LocalDate.now());
        
        Payment payment2 = new Payment();
        payment2.setAmount(200.00); // USER PREFERENCE: Convert BigDecimal to Double for MongoDB
        payment2.setPaymentDate(LocalDate.now().plusDays(1));
        
        debtCase.getPayments().add(payment1);
        debtCase.getPayments().add(payment2);

        // When
        Double total = debtCaseService.calculateTotalPaidAmount(debtCase); // USER PREFERENCE: Method returns Double for MongoDB

        // Then
        assertEquals(500.00, total); // USER PREFERENCE: Compare with Double value
    }
}
