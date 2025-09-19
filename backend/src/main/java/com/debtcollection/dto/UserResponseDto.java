package com.debtcollection.dto;

import lombok.Builder;
import lombok.Data;
import java.util.List;

@Data
@Builder
public class UserResponseDto {
    private String id;
    private String username;
    private List<String> roles;
    private boolean passwordExpired;
}

