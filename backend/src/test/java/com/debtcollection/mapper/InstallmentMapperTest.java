package com.debtcollection.mapper;

import com.debtcollection.dto.InstallmentDto;
import com.debtcollection.model.Installment;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

@ExtendWith(MockitoExtension.class)
class InstallmentMapperTest {

    @InjectMocks
    private InstallmentMapper installmentMapper;

    private Installment mockInstallment;
    private InstallmentDto mockInstallmentDto;

    @BeforeEach
    void setUp() {
        // CUSTOM IMPLEMENTATION: Setup Installment per test bidirezionali Entity <-> DTO
        mockInstallment = new Installment();
        mockInstallment.setInstallmentId("inst123");
        mockInstallment.setInstallmentNumber(1);
        mockInstallment.setAmount(new BigDecimal("750.25")); // BigDecimal anche in Model per Installment
        mockInstallment.setDueDate(LocalDateTime.of(2025, 2, 15, 0, 0));
        mockInstallment.setPaid(false);
        mockInstallment.setPaidDate(null);
        mockInstallment.setCreatedDate(LocalDateTime.of(2025, 1, 15, 10, 0));
        mockInstallment.setLastModifiedDate(LocalDateTime.of(2025, 1, 15, 10, 0));

        // Setup DTO per test conversione inversa
        mockInstallmentDto = new InstallmentDto();
        mockInstallmentDto.setId("inst456");
        mockInstallmentDto.setInstallmentNumber(2);
        mockInstallmentDto.setAmount(new BigDecimal("500.75"));
        mockInstallmentDto.setDueDate(LocalDateTime.of(2025, 3, 15, 0, 0));
        mockInstallmentDto.setPaid(true);
        mockInstallmentDto.setPaidDate(LocalDateTime.of(2025, 2, 20, 14, 30));
        mockInstallmentDto.setCreatedDate(LocalDateTime.of(2025, 1, 20, 10, 0));
        mockInstallmentDto.setLastModifiedDate(LocalDateTime.of(2025, 2, 20, 14, 30));
    }

    @Test
    void toDto_ShouldCorrectlyMapAllFields() {
        // When
        InstallmentDto result = installmentMapper.toDto(mockInstallment);

        // Then
        assertNotNull(result);
        assertEquals("inst123", result.getId());
        assertEquals(1, result.getInstallmentNumber());
        assertEquals(new BigDecimal("750.25"), result.getAmount());
        assertEquals(LocalDateTime.of(2025, 2, 15, 0, 0), result.getDueDate());
        assertFalse(result.getPaid());
        assertNull(result.getPaidDate());
        assertEquals(LocalDateTime.of(2025, 1, 15, 10, 0), result.getCreatedDate());
        assertEquals(LocalDateTime.of(2025, 1, 15, 10, 0), result.getLastModifiedDate());
    }

    @Test
    void toDto_ShouldReturnNullForNullInput() {
        // When
        InstallmentDto result = installmentMapper.toDto(null);

        // Then
        assertNull(result);
    }

    @Test
    void toDto_ShouldHandlePaidInstallment() {
        // Given
        mockInstallment.setPaid(true);
        mockInstallment.setPaidDate(LocalDateTime.of(2025, 2, 20, 14, 30));

        // When
        InstallmentDto result = installmentMapper.toDto(mockInstallment);

        // Then
        assertTrue(result.getPaid());
        assertEquals(LocalDateTime.of(2025, 2, 20, 14, 30), result.getPaidDate());
    }

    @Test
    void toEntity_ShouldCorrectlyMapAllFields() {
        // When
        Installment result = installmentMapper.toEntity(mockInstallmentDto);

        // Then
        assertNotNull(result);
        assertEquals("inst456", result.getInstallmentId());
        assertEquals(2, result.getInstallmentNumber());
        assertEquals(new BigDecimal("500.75"), result.getAmount());
        assertEquals(LocalDateTime.of(2025, 3, 15, 0, 0), result.getDueDate());
        assertTrue(result.getPaid());
        assertEquals(LocalDateTime.of(2025, 2, 20, 14, 30), result.getPaidDate());
        assertEquals(LocalDateTime.of(2025, 1, 20, 10, 0), result.getCreatedDate());
        assertEquals(LocalDateTime.of(2025, 2, 20, 14, 30), result.getLastModifiedDate());
    }

    @Test
    void toEntity_ShouldReturnNullForNullInput() {
        // When
        Installment result = installmentMapper.toEntity(null);

        // Then
        assertNull(result);
    }

    @Test
    void toEntity_ShouldHandleUnpaidInstallment() {
        // Given
        mockInstallmentDto.setPaid(false);
        mockInstallmentDto.setPaidDate(null);

        // When
        Installment result = installmentMapper.toEntity(mockInstallmentDto);

        // Then
        assertFalse(result.getPaid());
        assertNull(result.getPaidDate());
    }

    @Test
    void bidirectionalMapping_ShouldPreserveData() {
        // Given - Test mapping bidirezionale Entity -> DTO -> Entity
        Installment originalInstallment = mockInstallment;

        // When
        InstallmentDto dto = installmentMapper.toDto(originalInstallment);
        Installment mappedBackEntity = installmentMapper.toEntity(dto);

        // Then - CUSTOM IMPLEMENTATION: Verifica che i dati rimangano identici dopo mapping bidirezionale
        assertEquals(originalInstallment.getInstallmentId(), mappedBackEntity.getInstallmentId());
        assertEquals(originalInstallment.getInstallmentNumber(), mappedBackEntity.getInstallmentNumber());
        assertEquals(originalInstallment.getAmount(), mappedBackEntity.getAmount());
        assertEquals(originalInstallment.getDueDate(), mappedBackEntity.getDueDate());
        assertEquals(originalInstallment.getPaid(), mappedBackEntity.getPaid());
        assertEquals(originalInstallment.getPaidDate(), mappedBackEntity.getPaidDate());
    }

    @Test
    void toEntity_ShouldHandleNullMonetaryFields() {
        // Given
        mockInstallmentDto.setAmount(null);

        // When
        Installment result = installmentMapper.toEntity(mockInstallmentDto);

        // Then
        assertNull(result.getAmount());
    }
}
