package studio.thumbsup.server.quiz.authoring.dto;

import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;

public record AuthoringDetailedQuizResponse(Long quizId, int slotOrder, GeneratedQuizSet.GeneratedQuiz generated) {}
