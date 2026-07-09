package studio.thumbsup.server.quiz.generation;

import java.util.List;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizType;

/**
 * 엘리스 응답 JSON을 그대로 역직렬화하는 구조 — {@link QuizGenerationPromptBuilder}가 요구하는 스키마와 1:1로 맞춘다.
 * type/difficulty는 {@link QuizType}/{@link QuizDifficulty} enum 이름과 정확히 일치해야 한다(Jackson 기본 매핑).
 */
record GeneratedQuizSet(List<GeneratedQuiz> quizzes) {

    record GeneratedQuiz(
            QuizType type,
            QuizDifficulty difficulty,
            String questionText,
            String codeSnippet,
            String explanationSummary,
            String explanationExample,
            String wrongAnswerExplanation,
            String correctAnswer,
            List<GeneratedChoice> choices,
            List<List<String>> answerKeywords, // 바깥=빈칸 순서, 안쪽=그 빈칸의 동의어(하나만 맞아도 정답)
            List<GeneratedFollowUpQuestion> followUpQuestions,
            List<String> derivedConcepts,
            List<GeneratedKeyword> keywords) {}

    record GeneratedChoice(String content, boolean isCorrect) {}

    record GeneratedFollowUpQuestion(String content, boolean isPrimary) {}

    record GeneratedKeyword(String keyword, String description) {}
}
