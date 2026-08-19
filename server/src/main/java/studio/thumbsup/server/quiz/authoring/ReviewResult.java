package studio.thumbsup.server.quiz.authoring;

import java.util.List;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;

/**
 * REVIEW 잡의 브리지 결과 페이로드 — {@code {"reviewSummary": "...", "quizzes": [...]}}에 1:1로 매핑된다.
 * NEW draft면 quizzes가 5개, IMPROVE draft면 1개다(공유 HTTP 계약).
 */
public record ReviewResult(
        String reviewSummary,
        int schemaVersion,
        GeneratedQuizSet.GeneratedBriefing briefing,
        List<GeneratedQuizSet.GeneratedQuiz> quizzes) {

    /** 구형 IMPROVE REVIEW 결과 호환 생성자. */
    public ReviewResult(String reviewSummary, List<GeneratedQuizSet.GeneratedQuiz> quizzes) {
        this(reviewSummary, 1, null, quizzes);
    }
}
