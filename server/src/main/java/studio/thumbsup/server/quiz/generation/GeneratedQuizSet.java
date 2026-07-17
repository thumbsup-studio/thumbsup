package studio.thumbsup.server.quiz.generation;

import java.util.List;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizType;

/**
 * 엘리스 응답 JSON을 그대로 역직렬화하는 구조 — {@link QuizGenerationPromptBuilder}가 요구하는 스키마와 1:1로 맞춘다.
 * type/difficulty는 {@link QuizType}/{@link QuizDifficulty} enum 이름과 정확히 일치해야 한다(Jackson 기본 매핑).
 */
public record GeneratedQuizSet(List<GeneratedQuiz> quizzes) {

    public record GeneratedQuiz(
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

    public record GeneratedChoice(String content, boolean isCorrect) {}

    /**
     * 꼬리질문은 다른 문제로 라우팅되지 않고 스스로 콘텐츠를 갖는다(#108) — 읽기 전용 설명 화면이라
     * 풀이·채점이 없다. difficulty는 꼬리질문 자체의 난이도이며 부모 문제의 난이도와 무관하다.
     *
     * <p>keywords는 이 꼬리질문 전용 사전이다. 부모 문제의 keywords와 섞이지 않는다 — 꼬리질문은
     * 부모 지문에 없던 개념을 끌어오기 때문이다(예: 스택 문제의 꼬리질문에 등장하는 FIFO).
     */
    public record GeneratedFollowUpQuestion(
            String content,
            boolean isPrimary,
            QuizDifficulty difficulty,
            String oneLineAnswer,
            List<GeneratedFollowUpBlock> blocks,
            List<GeneratedKeyword> keywords) {}

    /**
     * 상세 정리 블록 한 칸. type을 모델에게 받지 않는 이유: {@code FollowUpBlockType}에 {@code TEXT}
     * 하나뿐이라 고를 여지를 주면 잘못된 값만 늘어난다. 저장 시 {@code TEXT}로 고정한다.
     */
    public record GeneratedFollowUpBlock(String label, String content) {}

    public record GeneratedKeyword(String keyword, String description) {}
}
