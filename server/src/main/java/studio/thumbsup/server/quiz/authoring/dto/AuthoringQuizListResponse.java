package studio.thumbsup.server.quiz.authoring.dto;

import java.util.List;

public record AuthoringQuizListResponse(List<AuthoringStepResponse> steps) {}
