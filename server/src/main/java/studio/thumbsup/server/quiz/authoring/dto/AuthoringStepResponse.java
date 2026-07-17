package studio.thumbsup.server.quiz.authoring.dto;

import java.util.List;

public record AuthoringStepResponse(int stepOrder, String topic, List<AuthoringQuizSummaryResponse> quizzes) {}
