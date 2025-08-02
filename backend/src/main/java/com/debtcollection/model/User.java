package com.debtcollection.model;

import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;
import org.springframework.data.mongodb.core.mapping.Field;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import java.util.Collection;
import java.util.HashSet;
import java.util.Set;
import java.util.stream.Collectors;

// USER PREFERENCE: Migrated from JPA @Entity to MongoDB @Document
@Document(collection = "users")
@Data
@NoArgsConstructor
public class User implements UserDetails {
    
    @Id
    private String id; // USER PREFERENCE: MongoDB ObjectId as String

    @Indexed(unique = true) // USER PREFERENCE: MongoDB unique index for username
    private String username;

    private String password;

    @Field("password_expired")
    private boolean passwordExpired = true;

    // USER PREFERENCE: MongoDB embedded array instead of JPA @ElementCollection
    private Set<String> roles = new HashSet<>();

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return roles.stream()
                .map(SimpleGrantedAuthority::new)
                .collect(Collectors.toSet());
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return true;
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return !passwordExpired;
    }

    @Override
    public boolean isEnabled() {
        return true;
    }
}
