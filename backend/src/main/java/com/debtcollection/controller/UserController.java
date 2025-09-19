package com.debtcollection.controller;

import com.debtcollection.dto.UserResponseDto;
import com.debtcollection.dto.UserCreateRequest;
import com.debtcollection.dto.UserUpdateRequest;
import com.debtcollection.model.User;
import com.debtcollection.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/users")
@RequiredArgsConstructor
public class UserController {
    private final UserService userService;

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    public List<UserResponseDto> getAllUsers() {
        return userService.findAll().stream()
                .map(this::toDto)
                .collect(Collectors.toList());
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public UserResponseDto createUser(@RequestBody UserCreateRequest request) {
        User user = userService.create(
                request.getUsername(),
                request.getPassword(),
                request.getRoles(),
                request.isPasswordExpired()
        );
        return toDto(user);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public UserResponseDto updateUser(@PathVariable String id, @RequestBody UserUpdateRequest request) {
        User user = userService.update(
                id,
                request.getUsername(),
                request.getPassword(),
                request.getRoles(),
                request.getPasswordExpired()
        );
        return toDto(user);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public void deleteUser(@PathVariable String id) {
        userService.delete(id);
    }

    private UserResponseDto toDto(User user) {
        return UserResponseDto.builder()
                .id(user.getId())
                .username(user.getUsername())
                .roles(user.getRoles().stream().toList())
                .passwordExpired(user.isPasswordExpired())
                .build();
    }
}

