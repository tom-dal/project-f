package com.debtcollection.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.io.IOException;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class JwtAuthenticationFilterTest {

    private JwtAuthenticationFilter filter;
    private JwtTokenProvider tokenProvider;
    private Authentication auth;

    @BeforeEach
    void setUp() {
        filter = new JwtAuthenticationFilter();
        tokenProvider = mock(JwtTokenProvider.class);
        ReflectionTestUtils.setField(filter, "tokenProvider", tokenProvider);
        UserDetails principal = new User("alice", "pwd", List.of(new SimpleGrantedAuthority("ROLE_USER")));
        auth = new UsernamePasswordAuthenticationToken(principal, "token", principal.getAuthorities());
    }

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void validNormalToken_setsAuthentication() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRequestURI("/cases");
        request.setMethod("GET");
        request.addHeader("Authorization", "Bearer VALID");
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        when(tokenProvider.validateToken("VALID")).thenReturn(true);
        when(tokenProvider.isPasswordChangeToken("VALID")).thenReturn(false);
        when(tokenProvider.getAuthentication("VALID")).thenReturn(auth);

        filter.doFilterInternal(request, response, chain);

        assertNotNull(SecurityContextHolder.getContext().getAuthentication());
        assertEquals("alice", SecurityContextHolder.getContext().getAuthentication().getName());
        verify(chain, times(1)).doFilter(request, response);
    }

    @Test
    void passwordChangeToken_correctEndpoint_allowed() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRequestURI("/auth/change-password");
        request.setMethod("POST");
        request.addHeader("Authorization", "Bearer CHANGE");
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        when(tokenProvider.validateToken("CHANGE")).thenReturn(true);
        when(tokenProvider.isPasswordChangeToken("CHANGE")).thenReturn(true);
        when(tokenProvider.getAuthentication("CHANGE")).thenReturn(auth);

        filter.doFilterInternal(request, response, chain);

        assertNotNull(SecurityContextHolder.getContext().getAuthentication());
        assertEquals(200, response.getStatus()); // default OK
        verify(chain, times(1)).doFilter(request, response);
    }

    @Test
    void passwordChangeToken_wrongEndpoint_forbidden() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRequestURI("/cases");
        request.setMethod("GET");
        request.addHeader("Authorization", "Bearer CHANGE");
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        when(tokenProvider.validateToken("CHANGE")).thenReturn(true);
        when(tokenProvider.isPasswordChangeToken("CHANGE")).thenReturn(true);

        filter.doFilterInternal(request, response, chain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());
        assertEquals(HttpServletResponse.SC_FORBIDDEN, response.getStatus());
        verify(chain, never()).doFilter(request, response);
    }

    @Test
    void invalidToken_noAuthentication() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRequestURI("/cases");
        request.setMethod("GET");
        request.addHeader("Authorization", "Bearer BAD");
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        when(tokenProvider.validateToken("BAD")).thenReturn(false);

        filter.doFilterInternal(request, response, chain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verify(chain, times(1)).doFilter(request, response);
    }

    @Test
    void missingHeader_doesNothing() throws Exception {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRequestURI("/cases");
        request.setMethod("GET");
        MockHttpServletResponse response = new MockHttpServletResponse();
        FilterChain chain = mock(FilterChain.class);

        filter.doFilterInternal(request, response, chain);

        assertNull(SecurityContextHolder.getContext().getAuthentication());
        verify(chain, times(1)).doFilter(request, response);
        verifyNoInteractions(tokenProvider);
    }
}

