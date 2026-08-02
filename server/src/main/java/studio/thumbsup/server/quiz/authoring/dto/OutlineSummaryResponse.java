package studio.thumbsup.server.quiz.authoring.dto;

public record OutlineSummaryResponse(
        Long outlineId, String title, String category, String status, int stepCount, int approvedStepCount) {}
