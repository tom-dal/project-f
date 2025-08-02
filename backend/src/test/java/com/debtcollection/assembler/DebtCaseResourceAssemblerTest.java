package com.debtcollection.assembler;

import com.debtcollection.dto.DebtCaseDto;
import com.debtcollection.model.CaseState;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.hateoas.EntityModel;
import org.springframework.hateoas.IanaLinkRelations;

import java.math.BigDecimal;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests for DebtCaseResourceAssembler
 * USER PREFERENCE: Test HATEOAS link generation and structure
 */
public class DebtCaseResourceAssemblerTest {

    private DebtCaseResourceAssembler assembler;
    private DebtCaseDto testDebtCaseDto;

    @BeforeEach
    void setUp() {
        assembler = new DebtCaseResourceAssembler();
        
        // Create test debt case DTO
        testDebtCaseDto = new DebtCaseDto();
        testDebtCaseDto.setId("507f1f77bcf86cd799439011"); // USER PREFERENCE: MongoDB ObjectId as String
        testDebtCaseDto.setDebtorName("Mario Rossi");
        testDebtCaseDto.setState(CaseState.MESSA_IN_MORA_DA_FARE);
        testDebtCaseDto.setOwedAmount(new BigDecimal("1500.00"));
        testDebtCaseDto.setCreatedDate(LocalDateTime.now().minusDays(10));
        testDebtCaseDto.setUpdatedDate(LocalDateTime.now().minusDays(1));
    }

    @Test
    void testToModelCreatesEntityModelWithCorrectData() {
        // Act
        EntityModel<DebtCaseDto> entityModel = assembler.toModel(testDebtCaseDto);

        // Assert
        assertNotNull(entityModel);
        assertEquals(testDebtCaseDto, entityModel.getContent());
    }

    @Test
    void testToModelIncludesSelfLink() {
        // Act
        EntityModel<DebtCaseDto> entityModel = assembler.toModel(testDebtCaseDto);

        // Assert
        assertTrue(entityModel.hasLink(IanaLinkRelations.SELF));
        
        String selfLink = entityModel.getRequiredLink(IanaLinkRelations.SELF).getHref();
        assertTrue(selfLink.contains("/cases/507f1f77bcf86cd799439011"));
    }

    @Test
    void testToModelIncludesUpdateLink() {
        // Act
        EntityModel<DebtCaseDto> entityModel = assembler.toModel(testDebtCaseDto);

        // Assert
        assertTrue(entityModel.hasLink("update"));
        
        String updateLink = entityModel.getRequiredLink("update").getHref();
        assertTrue(updateLink.contains("/cases/507f1f77bcf86cd799439011"));
    }

    @Test
    void testToModelIncludesDeleteLink() {
        // Act
        EntityModel<DebtCaseDto> entityModel = assembler.toModel(testDebtCaseDto);

        // Assert
        assertTrue(entityModel.hasLink("delete"));
        
        String deleteLink = entityModel.getRequiredLink("delete").getHref();
        assertTrue(deleteLink.contains("/cases/507f1f77bcf86cd799439011"));
    }

    @Test
    void testToModelWithNullIdHandling() {
        // Arrange
        testDebtCaseDto.setId(null);

        // Act & Assert - Spring HATEOAS will handle null ID gracefully, not throw exception
        EntityModel<DebtCaseDto> entityModel = assembler.toModel(testDebtCaseDto);
        assertNotNull(entityModel);
        assertEquals(testDebtCaseDto, entityModel.getContent());
    }

    @Test
    void testToModelLinksPointToCorrectController() {
        // Act
        EntityModel<DebtCaseDto> entityModel = assembler.toModel(testDebtCaseDto);

        // Assert
        String selfLink = entityModel.getRequiredLink(IanaLinkRelations.SELF).getHref();
        String updateLink = entityModel.getRequiredLink("update").getHref();
        String deleteLink = entityModel.getRequiredLink("delete").getHref();

        // All links should be generated based on DebtCaseController
        assertTrue(selfLink.contains("/cases"));
        assertTrue(updateLink.contains("/cases"));
        assertTrue(deleteLink.contains("/cases"));
        
        // Verify the specific ID is included
        assertTrue(selfLink.contains("/507f1f77bcf86cd799439011"));
        assertTrue(updateLink.contains("/507f1f77bcf86cd799439011"));
        assertTrue(deleteLink.contains("/507f1f77bcf86cd799439011"));
    }

    @Test
    void testAssemblerConsistencyAcrossMultipleCalls() {
        // Act
        EntityModel<DebtCaseDto> entityModel1 = assembler.toModel(testDebtCaseDto);
        EntityModel<DebtCaseDto> entityModel2 = assembler.toModel(testDebtCaseDto);

        // Assert - Both should generate identical links
        assertEquals(
            entityModel1.getRequiredLink(IanaLinkRelations.SELF).getHref(),
            entityModel2.getRequiredLink(IanaLinkRelations.SELF).getHref()
        );
        assertEquals(
            entityModel1.getRequiredLink("update").getHref(),
            entityModel2.getRequiredLink("update").getHref()
        );
    }

    @Test
    void testToModelWithDifferentIds() {
        // Arrange
        DebtCaseDto anotherCase = new DebtCaseDto();
        anotherCase.setId("507f1f77bcf86cd799439012");
        anotherCase.setDebtorName("Luigi Verdi");
        anotherCase.setState(CaseState.COMPLETATA);
        anotherCase.setOwedAmount(new BigDecimal("2500.00"));

        // Act
        EntityModel<DebtCaseDto> entityModel1 = assembler.toModel(testDebtCaseDto);
        EntityModel<DebtCaseDto> entityModel2 = assembler.toModel(anotherCase);

        // Assert - Links should be different based on ID
        String selfLink1 = entityModel1.getRequiredLink(IanaLinkRelations.SELF).getHref();
        String selfLink2 = entityModel2.getRequiredLink(IanaLinkRelations.SELF).getHref();
        
        assertTrue(selfLink1.contains("/507f1f77bcf86cd799439011"));
        assertTrue(selfLink2.contains("/507f1f77bcf86cd799439012"));
        assertNotEquals(selfLink1, selfLink2);
    }
}
