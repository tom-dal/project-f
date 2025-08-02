package com.debtcollection.model;

import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import org.springframework.data.mongodb.core.mapping.Field;
import org.springframework.data.mongodb.core.index.Indexed;

import java.time.LocalDateTime;

@Document(collection = "debt_case_audits")
@Data
@NoArgsConstructor
public class DebtCaseAudit {

    @Id
    private String id;

    @Field("debt_case_id")
    @Indexed
    private String debtCaseId;

    @Field("field_name")
    private String fieldName;

    @Field("old_value")
    private String oldValue;

    @Field("new_value")
    private String newValue;

    @Field("change_date")
    @Indexed
    private LocalDateTime changeDate;

    @Field("changed_by")
    private String changedBy;

    @Field("change_reason")
    private String changeReason;

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        DebtCaseAudit that = (DebtCaseAudit) o;
        return id != null && id.equals(that.id);
    }

    @Override
    public int hashCode() {
        return id != null ? id.hashCode() : 0;
    }
}
