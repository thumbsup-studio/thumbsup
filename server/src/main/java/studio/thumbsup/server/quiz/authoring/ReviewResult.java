package studio.thumbsup.server.quiz.authoring;

import java.util.List;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;

/**
 * REVIEW 잡의 브리지 결과 페이로드 — {@code {"reviewSummary": "...", "quizzes": [...]}}에 1:1로 매핑된다.
 * NEW draft면 quizzes가 5개, IMPROVE draft면 1개다(공유 HTTP 계약).
 */
public record ReviewResult(String reviewSummary, List<GeneratedQuizSet.GeneratedQuiz> quizzes) {}
