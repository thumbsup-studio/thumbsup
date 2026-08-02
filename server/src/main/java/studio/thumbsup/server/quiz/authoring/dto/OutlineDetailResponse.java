package studio.thumbsup.server.quiz.authoring.dto;

import java.util.List;

public record OutlineDetailResponse(
        Long outlineId, String title, String category, String status, String toc, List<OutlineStepResponse> steps) {}
