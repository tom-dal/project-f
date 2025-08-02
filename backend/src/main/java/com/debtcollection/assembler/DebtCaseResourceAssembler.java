package com.debtcollection.assembler;

import com.debtcollection.controller.DebtCaseController;
import com.debtcollection.dto.DebtCaseDto;
import org.springframework.hateoas.EntityModel;
import org.springframework.hateoas.server.RepresentationModelAssembler;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;

import static org.springframework.hateoas.server.mvc.WebMvcLinkBuilder.*;

/**
 * Resource assembler to add HATEOAS links to DebtCase DTOs
 */
@Component
public class DebtCaseResourceAssembler implements RepresentationModelAssembler<DebtCaseDto, EntityModel<DebtCaseDto>> {

    @Override
    @NonNull
    public EntityModel<DebtCaseDto> toModel(@NonNull DebtCaseDto debtCase) {
        EntityModel<DebtCaseDto> debtCaseModel = EntityModel.of(debtCase);
        
        // Self link - point to individual resource endpoint (when we add it)
        debtCaseModel.add(linkTo(DebtCaseController.class)
                .slash(debtCase.getId()).withSelfRel());
        
        // Update link
        debtCaseModel.add(linkTo(methodOn(DebtCaseController.class)
                .updateDebtCase(debtCase.getId(), null, null)).withRel("update"));
        
        // Delete link
        debtCaseModel.add(linkTo(methodOn(DebtCaseController.class)
                .deleteDebtCase(debtCase.getId(), null)).withRel("delete"));
        
        return debtCaseModel;
    }
}
