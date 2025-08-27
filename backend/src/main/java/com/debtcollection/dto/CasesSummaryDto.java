package com.debtcollection.dto;

import java.util.Map;

/**
 * Summary DTO for dashboard cards.
 * Aggregates counts for non-completed cases (excluding COMPLETATA).
 */
public record CasesSummaryDto(
        long totalActiveCases,
        long overdue,          // cases with nextDeadlineDate before today (non COMPLETATA)
        long dueToday,
        long dueNext7Days,
        Map<String, Long> states // key = state name (excluding COMPLETATA)
) {}
