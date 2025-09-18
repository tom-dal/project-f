package com.debtcollection.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import com.debtcollection.service.UserService;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;

import java.io.IOException;

@Component
@Slf4j
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    @Autowired
    private JwtTokenProvider tokenProvider;
    @Autowired
    private UserService userService;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        
        String requestURI = request.getRequestURI();
        String method = request.getMethod();
        log.info("JWT FILTER REQUEST - {} {}", method, requestURI);
        
        try {
            String jwt = getJwtFromRequest(request);
            log.info("🎫 JWT FILTER - Token present: {}", jwt != null ? "YES" : "NO");

            if (StringUtils.hasText(jwt) && tokenProvider.validateToken(jwt)) {
                log.info("✅ JWT FILTER - Token is valid");
                
                // Check if it's a password change token
                boolean isPasswordChangeToken = tokenProvider.isPasswordChangeToken(jwt);
                log.info("🔄 JWT FILTER - Is password change token: {}", isPasswordChangeToken);
                
                if (isPasswordChangeToken) {
                    // Only allow access to password change endpoint
                    if (!requestURI.endsWith("/auth/change-password")) {
                        log.warn("❌ JWT FILTER - Password change token used for wrong endpoint: {}", requestURI);
                        response.sendError(HttpServletResponse.SC_FORBIDDEN, "This token can only be used for password change");
                        return;
                    }
                    log.info("✅ JWT FILTER - Password change token used for correct endpoint");
                }
                Authentication authentication = tokenProvider.getAuthentication(jwt);
                // CUSTOM IMPLEMENTATION: Fallback - if token has no authorities (e.g., legacy/limited token) load from DB
                if (authentication.getAuthorities() == null || authentication.getAuthorities().isEmpty()) {
                    try {
                        UserDetails userDetails = userService.loadUserByUsername(authentication.getName());
                        authentication = new UsernamePasswordAuthenticationToken(userDetails, authentication.getCredentials(), userDetails.getAuthorities());
                        log.info("[FALLBACK] Loaded authorities from DB for user {} -> {}", userDetails.getUsername(), userDetails.getAuthorities());
                    } catch (Exception ex) {
                        log.warn("[FALLBACK] Unable to load user details for {}: {}", authentication.getName(), ex.getMessage());
                    }
                }
                SecurityContextHolder.getContext().setAuthentication(authentication);
                log.info("🔐 JWT FILTER - Authentication set in security context: {}", authentication.getName());
            } else if (jwt != null) {
                log.warn("❌ JWT FILTER - Token present but invalid");
            }
        } catch (Exception ex) {
            log.error("💥 JWT FILTER ERROR - Could not set user authentication: {}", ex.getMessage());
            log.error("🔍 JWT FILTER ERROR - Exception: ", ex);
        }

        log.info("➡️ JWT FILTER - Continuing filter chain for: {} {}", method, requestURI);
        filterChain.doFilter(request, response);
    }

    private String getJwtFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        log.info("🔑 JWT FILTER - Authorization header: {}", bearerToken != null ? "Bearer ***" : "NONE");
        
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            String token = bearerToken.substring(7);
            log.info("🎫 JWT FILTER - Extracted token");
            return token;
        }
        return null;
    }
}
