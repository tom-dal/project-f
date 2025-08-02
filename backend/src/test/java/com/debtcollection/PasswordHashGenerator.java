package com.debtcollection;

import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

public class PasswordHashGenerator {
    public static void main(String[] args) {
        BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
        String plainPassword = "admin";
        String hashedPassword = encoder.encode(plainPassword);
        System.out.println("Plain: " + plainPassword);
        System.out.println("Hash: " + hashedPassword);
        System.out.println("Test with existing hash: " + encoder.matches(plainPassword, "$2a$10$DOwlbeUMCmHnqqRFPYAj7OJK1fH5Bq6/1OLO1/KQ0oMp7yoL0LV6y"));
    }
}
