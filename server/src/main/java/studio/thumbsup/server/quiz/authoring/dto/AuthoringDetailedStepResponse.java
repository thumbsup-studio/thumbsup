package studio.thumbsup.server.quiz.authoring.dto;

import java.util.List;

public record AuthoringDetailedStepResponse(int stepOrder, String topic, List<AuthoringDetailedQuizResponse> quizzes) {}
