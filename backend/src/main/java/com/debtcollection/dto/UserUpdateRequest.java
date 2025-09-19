package com.debtcollection.dto;

import lombok.Data;
import java.util.List;

@Data
public class UserUpdateRequest {
    private String username; // opzionale
    private String password; // opzionale
    private List<String> roles; // opzionale
    private Boolean passwordExpired; // opzionale
}

