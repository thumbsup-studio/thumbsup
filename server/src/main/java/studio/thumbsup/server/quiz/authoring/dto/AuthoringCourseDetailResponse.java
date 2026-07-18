package studio.thumbsup.server.quiz.authoring.dto;

import java.util.List;

public record AuthoringCourseDetailResponse(Long courseId, String title, List<AuthoringDetailedStepResponse> steps) {}
