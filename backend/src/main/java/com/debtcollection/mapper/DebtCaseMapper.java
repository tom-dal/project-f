package com.debtcollection.mapper;

import com.debtcollection.dto.DebtCaseDto;
import com.debtcollection.model.DebtCase;
import com.debtcollection.model.Payment;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.Objects;

@Service
@RequiredArgsConstructor
public class DebtCaseMapper {

    private final PaymentMapper paymentMapper;
    private final InstallmentMapper installmentMapper;

    public DebtCaseDto toDto(DebtCase debtCase) {
        DebtCaseDto dto = new DebtCaseDto();
        // USER PREFERENCE: Manual mapping for monetary and date fields, avoid BeanUtils
        dto.setId(debtCase.getId());
        dto.setDebtorName(debtCase.getDebtorName());
        dto.setOwedAmount(debtCase.getOwedAmount() != null ? BigDecimal.valueOf(debtCase.getOwedAmount()) : null);
        dto.setState(debtCase.getCurrentState());
        dto.setNotes(debtCase.getNotes());
        dto.setCreatedDate(debtCase.getCreatedDate());
        dto.setUpdatedDate(debtCase.getLastModifiedDate());
        dto.setLastStateDate(debtCase.getCurrentStateDate());
        dto.setNextDeadlineDate(debtCase.getNextDeadlineDate() != null ? debtCase.getNextDeadlineDate().toLocalDate() : null);
        dto.setCreatedBy(debtCase.getCreatedBy());
        dto.setLastModifiedBy(debtCase.getLastModifiedBy());
        dto.setLastModifiedDate(debtCase.getLastModifiedDate());
        dto.setOngoingNegotiations(debtCase.getOngoingNegotiations());
        dto.setHasInstallmentPlan(debtCase.getHasInstallmentPlan());
        dto.setPaid(debtCase.getPaid());
        // Calculate amounts for frontend convenience
        Double totalPaid = debtCase.getPayments() != null ? debtCase.getPayments().stream()
                .filter(Objects::nonNull)
                .map(Payment::getAmount)
                .filter(Objects::nonNull)
                .reduce(0.0, Double::sum) : 0.0;
        dto.setTotalPaidAmount(BigDecimal.valueOf(totalPaid));
        dto.setRemainingAmount(
                dto.getOwedAmount() != null ? dto.getOwedAmount().subtract(BigDecimal.valueOf(totalPaid)) : null
        );
        // Map collections
        dto.setPayments(debtCase.getPayments() != null ? debtCase.getPayments().stream().filter(Objects::nonNull).map(paymentMapper::toDto).toList() : null);
        dto.setInstallments(debtCase.getInstallments() != null ? debtCase.getInstallments().stream().filter(Objects::nonNull).map(installmentMapper::toDto).toList() : null);
        return dto;
    }
}
