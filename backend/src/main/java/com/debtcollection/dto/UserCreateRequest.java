package com.debtcollection.dto;

import lombok.Data;
import java.util.List;

@Data
public class UserCreateRequest {
    private String username;
    private String password;
    private List<String> roles;
    private boolean passwordExpired;
}

