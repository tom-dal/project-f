package com.debtcollection.mapper;

import com.debtcollection.dto.DebtCaseDto;
import com.debtcollection.model.DebtCase;
import com.debtcollection.model.Payment;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.BeanUtils;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;

@Service
@RequiredArgsConstructor
public class DebtCaseMapper {

    private final PaymentMapper paymentMapper;
    private final InstallmentMapper installmentMapper;

    public DebtCaseDto toDto(DebtCase debtCase) {
        DebtCaseDto dto = new DebtCaseDto();
        BeanUtils.copyProperties(debtCase, dto);
        
        // USER PREFERENCE: Conversione esplicita Double -> BigDecimal per owedAmount
        dto.setOwedAmount(BigDecimal.valueOf(debtCase.getOwedAmount()));

        // Usa i nuovi campi diretti
        dto.setState(debtCase.getCurrentState());
        dto.setLastStateDate(debtCase.getCurrentStateDate());
        dto.setNextDeadlineDate(debtCase.getNextDeadlineDate() != null ? 
            debtCase.getNextDeadlineDate().toLocalDate() : null);
        
        // CUSTOM IMPLEMENTATION: Explicit auditing fields mapping
        dto.setCreatedBy(debtCase.getCreatedBy());
        dto.setLastModifiedBy(debtCase.getLastModifiedBy());
        dto.setLastModifiedDate(debtCase.getLastModifiedDate());
        // updatedDate è un alias per lastModifiedDate
        dto.setUpdatedDate(debtCase.getLastModifiedDate());
        
        // CUSTOM IMPLEMENTATION: Business logic fields
        dto.setHasInstallmentPlan(debtCase.getHasInstallmentPlan());
        dto.setPaid(debtCase.getPaid());
        
        // Calculate amounts for frontend convenience
        Double totalPaid = debtCase.getPayments().stream()
                .map(Payment::getAmount)
                .reduce(0.0, Double::sum);
        dto.setTotalPaidAmount(BigDecimal.valueOf(totalPaid));
        dto.setRemainingAmount(BigDecimal.valueOf(debtCase.getOwedAmount()).subtract(BigDecimal.valueOf(totalPaid)));

        // Map collections
        dto.setPayments(debtCase.getPayments().stream().map(paymentMapper::toDto).toList());
        dto.setInstallments(debtCase.getInstallments().stream().map(installmentMapper::toDto).toList());
        dto.setOngoingNegotiations(debtCase.getOngoingNegotiations());

        return dto;
    }

}
