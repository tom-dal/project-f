package com.debtcollection.mapper;

import com.debtcollection.dto.PaymentDto;
import com.debtcollection.model.Payment;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

@ExtendWith(MockitoExtension.class)
class PaymentMapperTest {

    @InjectMocks
    private PaymentMapper paymentMapper;

    private Payment mockPayment;

    @BeforeEach
    void setUp() {
        // CUSTOM IMPLEMENTATION: Setup Payment con dati realistici per test conversioni monetarie
        mockPayment = new Payment();
        mockPayment.setPaymentId("payment123");
        mockPayment.setAmount(1234.56); // USER PREFERENCE: Double nel Model per MongoDB
        mockPayment.setPaymentDate(LocalDate.of(2025, 1, 15));
        mockPayment.setCreatedDate(LocalDateTime.of(2025, 1, 15, 10, 30));
        mockPayment.setLastModifiedDate(LocalDateTime.of(2025, 1, 15, 10, 30));
    }

    @Test
    void toDto_ShouldCorrectlyConvertDoubleToBigDecimal() {
        // When
        PaymentDto result = paymentMapper.toDto(mockPayment);

        // Then - USER PREFERENCE: Verifica conversione Double -> BigDecimal per precisione monetaria
        assertNotNull(result);
        assertEquals("payment123", result.getId());
        assertEquals(new BigDecimal("1234.56"), result.getAmount());
        assertEquals(LocalDate.of(2025, 1, 15), result.getPaymentDate());
    }

    @Test
    void toDto_ShouldHandleNullAmount() {
        // Given
        mockPayment.setAmount(null);

        // When
        PaymentDto result = paymentMapper.toDto(mockPayment);

        // Then
        assertNotNull(result);
        assertNull(result.getAmount());
        assertEquals("payment123", result.getId());
    }

    @Test
    void toDto_ShouldMapAllFields() {
        // When
        PaymentDto result = paymentMapper.toDto(mockPayment);

        // Then
        assertEquals("payment123", result.getId());
        assertEquals(new BigDecimal("1234.56"), result.getAmount());
        assertEquals(LocalDate.of(2025, 1, 15), result.getPaymentDate());
        assertEquals(LocalDateTime.of(2025, 1, 15, 10, 30), result.getCreatedDate());
        assertEquals(LocalDateTime.of(2025, 1, 15, 10, 30), result.getLastModifiedDate());
    }

    @Test
    void toDto_ShouldHandlePreciseDecimalValues() {
        // Given - Test per precisione con decimali complessi
        mockPayment.setAmount(999.99);

        // When
        PaymentDto result = paymentMapper.toDto(mockPayment);

        // Then - CUSTOM IMPLEMENTATION: Verifica precisione conversione monetaria
        assertEquals(new BigDecimal("999.99"), result.getAmount());
    }

    @Test
    void toDto_ShouldHandleVerySmallAmounts() {
        // Given
        mockPayment.setAmount(0.01); // 1 centesimo

        // When
        PaymentDto result = paymentMapper.toDto(mockPayment);

        // Then
        assertEquals(new BigDecimal("0.01"), result.getAmount());
    }

    @Test
    void toDto_ShouldHandleZeroAmount() {
        // Given
        mockPayment.setAmount(0.0);

        // When
        PaymentDto result = paymentMapper.toDto(mockPayment);

        // Then
        assertEquals(new BigDecimal("0.0"), result.getAmount());
    }

    @Test
    void toDto_ShouldHandleLargeAmounts() {
        // Given
        mockPayment.setAmount(999999.99);

        // When
        PaymentDto result = paymentMapper.toDto(mockPayment);

        // Then
        assertEquals(new BigDecimal("999999.99"), result.getAmount());
    }

    @Test
    void toDto_ShouldHandleNullDates() {
        // Given
        mockPayment.setPaymentDate(null);
        mockPayment.setCreatedDate(null);
        mockPayment.setLastModifiedDate(null);

        // When
        PaymentDto result = paymentMapper.toDto(mockPayment);

        // Then
        assertNotNull(result);
        assertEquals("payment123", result.getId());
        assertEquals(new BigDecimal("1234.56"), result.getAmount());
        assertNull(result.getPaymentDate());
        assertNull(result.getCreatedDate());
        assertNull(result.getLastModifiedDate());
    }

    @Test
    void toDto_ShouldHandleComplexMonetaryCalculations() {
        // Given - Test per calcoli complessi tipici nel business
        mockPayment.setAmount(1500.0 / 3.0); // Divisione che genera decimali periodici

        // When
        PaymentDto result = paymentMapper.toDto(mockPayment);

        // Then - CUSTOM IMPLEMENTATION: Verifica gestione precisione per calcoli complessi
        assertNotNull(result.getAmount());
        assertTrue(result.getAmount().doubleValue() > 499.0);
        assertTrue(result.getAmount().doubleValue() < 501.0);
    }
}
