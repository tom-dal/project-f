package com.debtcollection.mapper;

import com.debtcollection.dto.DebtCaseDto;
import com.debtcollection.dto.InstallmentDto;
import com.debtcollection.dto.PaymentDto;
import com.debtcollection.model.CaseState;
import com.debtcollection.model.DebtCase;
import com.debtcollection.model.Installment;
import com.debtcollection.model.Payment;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DebtCaseMapperTest {

    @Mock
    private PaymentMapper paymentMapper;

    @Mock
    private InstallmentMapper installmentMapper;

    @InjectMocks
    private DebtCaseMapper debtCaseMapper;

    private DebtCase mockDebtCase;
    private Payment mockPayment1;
    private Payment mockPayment2;
    private Installment mockInstallment;
    private PaymentDto mockPaymentDto1;
    private PaymentDto mockPaymentDto2;
    private InstallmentDto mockInstallmentDto;

    @BeforeEach
    void setUp() {
        // CUSTOM IMPLEMENTATION: Setup DebtCase con dati realistici per test conversioni monetarie
        mockDebtCase = new DebtCase();
        mockDebtCase.setId("debt123");
        mockDebtCase.setDebtorName("Mario Rossi");
        mockDebtCase.setOwedAmount(1500.50); // USER PREFERENCE: Double nel Model per MongoDB
        mockDebtCase.setCurrentState(CaseState.MESSA_IN_MORA_DA_FARE);
        mockDebtCase.setCurrentStateDate(LocalDateTime.of(2025, 1, 15, 10, 0));
        mockDebtCase.setCreatedDate(LocalDateTime.of(2025, 1, 10, 9, 0));
        mockDebtCase.setCreatedBy("admin");
        mockDebtCase.setLastModifiedBy("admin");
        mockDebtCase.setLastModifiedDate(LocalDateTime.of(2025, 1, 15, 10, 0));
        mockDebtCase.setHasInstallmentPlan(false);
        mockDebtCase.setPaid(false);
        mockDebtCase.setOngoingNegotiations(false);

        // Setup pagamenti per test calcoli totali
        mockPayment1 = new Payment();
        mockPayment1.setPaymentId("pay1");
        mockPayment1.setAmount(500.25); // USER PREFERENCE: Double nel Model
        mockPayment1.setPaymentDate(LocalDate.of(2025, 1, 12));

        mockPayment2 = new Payment();
        mockPayment2.setPaymentId("pay2");
        mockPayment2.setAmount(300.75); // USER PREFERENCE: Double nel Model
        mockPayment2.setPaymentDate(LocalDate.of(2025, 1, 14));

        mockDebtCase.setPayments(Arrays.asList(mockPayment1, mockPayment2));

        // Setup installment
        mockInstallment = new Installment();
        mockInstallment.setInstallmentId("inst1"); // Corretto: usa installmentId
        mockInstallment.setAmount(BigDecimal.valueOf(750.25));
        mockDebtCase.setInstallments(Arrays.asList(mockInstallment));

        // Setup DTO mock per mapper dependencies
        mockPaymentDto1 = new PaymentDto();
        mockPaymentDto1.setId("pay1");
        mockPaymentDto1.setAmount(new BigDecimal("500.25")); // USER PREFERENCE: BigDecimal nei DTO

        mockPaymentDto2 = new PaymentDto();
        mockPaymentDto2.setId("pay2");
        mockPaymentDto2.setAmount(new BigDecimal("300.75")); // USER PREFERENCE: BigDecimal nei DTO

        mockInstallmentDto = new InstallmentDto();
        mockInstallmentDto.setId("inst1");
        mockInstallmentDto.setAmount(new BigDecimal("750.25"));
    }

    @Test
    void toDto_ShouldCorrectlyConvertMonetaryFields() {
        // Given
        when(paymentMapper.toDto(mockPayment1)).thenReturn(mockPaymentDto1);
        when(paymentMapper.toDto(mockPayment2)).thenReturn(mockPaymentDto2);
        when(installmentMapper.toDto(mockInstallment)).thenReturn(mockInstallmentDto);

        // When
        DebtCaseDto result = debtCaseMapper.toDto(mockDebtCase);

        // Then - CUSTOM IMPLEMENTATION: Verifica conversione Double -> BigDecimal per owedAmount
        assertNotNull(result);
        assertEquals(0, new BigDecimal("1500.50").compareTo(result.getOwedAmount())); // Usa compareTo per BigDecimal
        assertEquals("debt123", result.getId());
        assertEquals("Mario Rossi", result.getDebtorName());
    }

    @Test
    void toDto_ShouldCalculateCorrectTotalPaidAmount() {
        // Given
        when(paymentMapper.toDto(any(Payment.class))).thenReturn(mockPaymentDto1);
        when(installmentMapper.toDto(any(Installment.class))).thenReturn(mockInstallmentDto);

        // When
        DebtCaseDto result = debtCaseMapper.toDto(mockDebtCase);

        // Then - CUSTOM IMPLEMENTATION: Verifica calcolo totale pagato (500.25 + 300.75 = 801.00)
        assertEquals(0, new BigDecimal("801.00").compareTo(result.getTotalPaidAmount())); // Usa compareTo per BigDecimal
        verify(paymentMapper, times(2)).toDto(any(Payment.class));
    }

    @Test
    void toDto_ShouldCalculateCorrectRemainingAmount() {
        // Given
        when(paymentMapper.toDto(any(Payment.class))).thenReturn(mockPaymentDto1);
        when(installmentMapper.toDto(any(Installment.class))).thenReturn(mockInstallmentDto);

        // When
        DebtCaseDto result = debtCaseMapper.toDto(mockDebtCase);

        // Then - CUSTOM IMPLEMENTATION: Verifica calcolo resto (1500.50 - 801.00 = 699.50)
        assertEquals(0, new BigDecimal("699.50").compareTo(result.getRemainingAmount())); // Usa compareTo per BigDecimal
    }

    @Test
    void toDto_ShouldHandleEmptyPaymentsList() {
        // Given
        mockDebtCase.setPayments(new ArrayList<>());
        when(installmentMapper.toDto(any(Installment.class))).thenReturn(mockInstallmentDto);

        // When
        DebtCaseDto result = debtCaseMapper.toDto(mockDebtCase);

        // Then
        assertEquals(0, new BigDecimal("0.00").compareTo(result.getTotalPaidAmount())); // Usa compareTo per BigDecimal
        assertEquals(0, new BigDecimal("1500.50").compareTo(result.getRemainingAmount())); // Usa compareTo per BigDecimal
        assertTrue(result.getPayments().isEmpty());
        verify(paymentMapper, never()).toDto(any(Payment.class));
    }

    @Test
    void toDto_ShouldMapAllStateFields() {
        // Given
        when(paymentMapper.toDto(any(Payment.class))).thenReturn(mockPaymentDto1);
        when(installmentMapper.toDto(any(Installment.class))).thenReturn(mockInstallmentDto);

        // When
        DebtCaseDto result = debtCaseMapper.toDto(mockDebtCase);

        // Then
        assertEquals(CaseState.MESSA_IN_MORA_DA_FARE, result.getState());
        assertEquals(LocalDateTime.of(2025, 1, 15, 10, 0), result.getLastStateDate());
        assertNull(result.getNextDeadlineDate()); // Non impostato nel mock
    }

    @Test
    void toDto_ShouldMapAuditingFields() {
        // Given
        when(paymentMapper.toDto(any(Payment.class))).thenReturn(mockPaymentDto1);
        when(installmentMapper.toDto(any(Installment.class))).thenReturn(mockInstallmentDto);

        // When
        DebtCaseDto result = debtCaseMapper.toDto(mockDebtCase);

        // Then - CUSTOM IMPLEMENTATION: Verifica mapping campi di auditing
        assertEquals("admin", result.getCreatedBy());
        assertEquals("admin", result.getLastModifiedBy());
        assertEquals(LocalDateTime.of(2025, 1, 15, 10, 0), result.getLastModifiedDate());
        assertEquals(LocalDateTime.of(2025, 1, 15, 10, 0), result.getUpdatedDate()); // Alias
        assertEquals(LocalDateTime.of(2025, 1, 10, 9, 0), result.getCreatedDate());
    }

    @Test
    void toDto_ShouldMapBusinessLogicFields() {
        // Given
        when(paymentMapper.toDto(any(Payment.class))).thenReturn(mockPaymentDto1);
        when(installmentMapper.toDto(any(Installment.class))).thenReturn(mockInstallmentDto);

        // When
        DebtCaseDto result = debtCaseMapper.toDto(mockDebtCase);

        // Then
        assertFalse(result.getHasInstallmentPlan());
        assertFalse(result.getPaid());
        assertFalse(result.getOngoingNegotiations());
    }

    @Test
    void toDto_ShouldHandleNextDeadlineDateConversion() {
        // Given
        mockDebtCase.setNextDeadlineDate(LocalDateTime.of(2025, 2, 15, 23, 59));
        when(paymentMapper.toDto(any(Payment.class))).thenReturn(mockPaymentDto1);
        when(installmentMapper.toDto(any(Installment.class))).thenReturn(mockInstallmentDto);

        // When
        DebtCaseDto result = debtCaseMapper.toDto(mockDebtCase);

        // Then - CUSTOM IMPLEMENTATION: Verifica conversione LocalDateTime -> LocalDate
        assertEquals(LocalDate.of(2025, 2, 15), result.getNextDeadlineDate());
    }

    @Test
    void toDto_ShouldHandlePreciseMonetaryCalculations() {
        // Given - Test per precisione con decimali complessi
        mockDebtCase.setOwedAmount(1000.33);

        Payment payment1 = new Payment();
        payment1.setAmount(333.11); // 1/3 circa
        Payment payment2 = new Payment();
        payment2.setAmount(333.11); // 1/3 circa
        Payment payment3 = new Payment();
        payment3.setAmount(333.11); // 1/3 circa

        mockDebtCase.setPayments(Arrays.asList(payment1, payment2, payment3));

        when(paymentMapper.toDto(any(Payment.class))).thenReturn(mockPaymentDto1);
        when(installmentMapper.toDto(any(Installment.class))).thenReturn(mockInstallmentDto);

        // When
        DebtCaseDto result = debtCaseMapper.toDto(mockDebtCase);

        // Then - CUSTOM IMPLEMENTATION: Verifica precisione calcoli monetari
        assertEquals(new BigDecimal("1000.33"), result.getOwedAmount());
        assertEquals(new BigDecimal("999.33"), result.getTotalPaidAmount()); // 333.11 * 3
        assertEquals(new BigDecimal("1.00"), result.getRemainingAmount()); // 1000.33 - 999.33
    }

    @Test
    void toDto_ShouldMapCollections() {
        // Given
        when(paymentMapper.toDto(mockPayment1)).thenReturn(mockPaymentDto1);
        when(paymentMapper.toDto(mockPayment2)).thenReturn(mockPaymentDto2);
        when(installmentMapper.toDto(mockInstallment)).thenReturn(mockInstallmentDto);

        // When
        DebtCaseDto result = debtCaseMapper.toDto(mockDebtCase);

        // Then
        assertEquals(2, result.getPayments().size());
        assertEquals(1, result.getInstallments().size());
        assertEquals("pay1", result.getPayments().get(0).getId());
        assertEquals("inst1", result.getInstallments().get(0).getId());

        verify(paymentMapper).toDto(mockPayment1);
        verify(paymentMapper).toDto(mockPayment2);
        verify(installmentMapper).toDto(mockInstallment);
    }
}
