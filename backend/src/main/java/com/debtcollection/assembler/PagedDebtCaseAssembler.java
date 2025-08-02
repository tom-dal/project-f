package com.debtcollection.assembler;

import com.debtcollection.dto.DebtCaseDto;
import com.debtcollection.dto.DebtCaseFilterRequest;
import org.springframework.data.domain.Page;
import org.springframework.data.web.PagedResourcesAssembler;
import org.springframework.hateoas.EntityModel;
import org.springframework.hateoas.PagedModel;
import org.springframework.stereotype.Component;

/**
 * Assembler for creating paginated responses with HATEOAS navigation links
 */
@Component
public class PagedDebtCaseAssembler {
    
    private final DebtCaseResourceAssembler debtCaseAssembler;
    private final PagedResourcesAssembler<DebtCaseDto> pagedResourcesAssembler;
    
    public PagedDebtCaseAssembler(DebtCaseResourceAssembler debtCaseAssembler,
                                  PagedResourcesAssembler<DebtCaseDto> pagedResourcesAssembler) {
        this.debtCaseAssembler = debtCaseAssembler;
        this.pagedResourcesAssembler = pagedResourcesAssembler;
    }
    
    public PagedModel<EntityModel<DebtCaseDto>> toPagedModel(
            Page<DebtCaseDto> page, 
            DebtCaseFilterRequest filterRequest) {
        
        // Use PagedResourcesAssembler to create the full model with links
        // Then we'll override the embedded relation name
        return pagedResourcesAssembler.toModel(page, debtCaseAssembler);
    }
}
