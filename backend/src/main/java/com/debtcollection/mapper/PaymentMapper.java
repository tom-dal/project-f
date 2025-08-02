package com.debtcollection.mapper;

import com.debtcollection.dto.PaymentDto;
import com.debtcollection.model.Payment;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;

@Service
public class PaymentMapper {

    public PaymentDto toDto(Payment payment) {
        PaymentDto dto = new PaymentDto();
        dto.setId(payment.getPaymentId());
        // USER PREFERENCE: Manual conversion from Double (Model) to BigDecimal (DTO) for monetary precision
        dto.setAmount(payment.getAmount() != null ? BigDecimal.valueOf(payment.getAmount()) : null);
        dto.setPaymentDate(payment.getPaymentDate());
        dto.setCreatedDate(payment.getCreatedDate());
        dto.setLastModifiedDate(payment.getLastModifiedDate());

        // USER PREFERENCE: Payment is now embedded - no debtCase reference needed
        // The debtCaseId will be set by the service layer when calling this mapper

        return dto;
    }
}
