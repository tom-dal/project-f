package com.debtcollection.model;

import com.fasterxml.jackson.annotation.JsonValue;
import com.fasterxml.jackson.annotation.JsonCreator;

// USER PREFERENCE: Enum per gestire gli stati dei casi di recupero crediti
// CUSTOM IMPLEMENTATION: Added Jackson annotations for proper HTTP parameter serialization
public enum CaseState {
    MESSA_IN_MORA_DA_FARE,
    MESSA_IN_MORA_INVIATA,
    DEPOSITO_RICORSO,
    DECRETO_INGIUNTIVO_DA_NOTIFICARE,
    DECRETO_INGIUNTIVO_NOTIFICATO,
    CONTESTAZIONE_DA_RISCONTRARE,
    PIGNORAMENTO,
    PRECETTO,
    COMPLETATA;

    // CUSTOM IMPLEMENTATION: Jackson serialization for HTTP parameters
    @JsonValue
    public String toValue() {
        return this.name();
    }

    // CUSTOM IMPLEMENTATION: Jackson deserialization for HTTP parameters  
    @JsonCreator
    public static CaseState fromValue(String value) {
        if (value == null) {
            return null;
        }
        try {
            return CaseState.valueOf(value.toUpperCase());
        } catch (IllegalArgumentException e) {
            // Handle case-insensitive matching
            for (CaseState state : CaseState.values()) {
                if (state.name().equalsIgnoreCase(value)) {
                    return state;
                }
            }
            throw new IllegalArgumentException("Invalid CaseState value: " + value);
        }
    }
}
