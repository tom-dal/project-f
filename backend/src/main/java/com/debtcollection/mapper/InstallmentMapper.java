package com.debtcollection.mapper;

import com.debtcollection.dto.InstallmentDto;
import com.debtcollection.model.Installment;
import org.springframework.stereotype.Component;

@Component
public class InstallmentMapper {

    public InstallmentDto toDto(Installment installment) {
        if (installment == null) {
            return null;
        }

        InstallmentDto dto = new InstallmentDto();
        // USER PREFERENCE: Installment is now embedded - use installmentId instead of id
        dto.setId(installment.getInstallmentId()); // Use internal embedded document ID
        // USER PREFERENCE: debtCaseId will be set by service layer when calling this mapper
        dto.setInstallmentNumber(installment.getInstallmentNumber());
        dto.setAmount(installment.getAmount());
        dto.setDueDate(installment.getDueDate());
        dto.setPaid(installment.getPaid());
        dto.setPaidDate(installment.getPaidDate());
        dto.setCreatedDate(installment.getCreatedDate());
        dto.setLastModifiedDate(installment.getLastModifiedDate());

        return dto;
    }

    public Installment toEntity(InstallmentDto dto) {
        if (dto == null) {
            return null;
        }

        Installment installment = new Installment();
        // USER PREFERENCE: Set installmentId for embedded document
        installment.setInstallmentId(dto.getId());
        installment.setInstallmentNumber(dto.getInstallmentNumber());
        installment.setAmount(dto.getAmount());
        installment.setDueDate(dto.getDueDate());
        installment.setPaid(dto.getPaid());
        installment.setPaidDate(dto.getPaidDate());
        installment.setCreatedDate(dto.getCreatedDate());
        installment.setLastModifiedDate(dto.getLastModifiedDate());

        return installment;
    }
}