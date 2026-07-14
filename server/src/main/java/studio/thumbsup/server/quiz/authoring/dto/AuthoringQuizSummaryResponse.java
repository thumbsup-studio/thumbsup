package studio.thumbsup.server.quiz.authoring.dto;

import studio.thumbsup.server.quiz.Quiz;

public record AuthoringQuizSummaryResponse(
        Long quizId, int slotOrder, String type, String difficulty, String questionText) {

    public static AuthoringQuizSummaryResponse from(Quiz quiz) {
        return new AuthoringQuizSummaryResponse(
                quiz.getId(),
                quiz.getSlotOrder(),
                quiz.getType().name(),
                quiz.getDifficulty().name(),
                quiz.getQuestionText());
    }
}
