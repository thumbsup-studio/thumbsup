package studio.thumbsup.server.quiz.authoring;

import studio.thumbsup.server.quiz.generation.QuizPreset;

/**
 * 브리지 CLI의 {@code --json-schema}/{@code --output-schema}에 전달할 얕은 가드 — 필수 필드·타입만
 * 확인한다. 깊은 검증(슬롯 순서·마커·꼬리질문 상세 등)은 {@link studio.thumbsup.server.quiz.generation.GeneratedQuizValidator}가
 * 서버에서 수행한다.
 */
public final class AuthoringOutputSchemas {

    private static final String GENERATE_TEMPLATE = """
            {"type":"object","required":["schemaVersion","briefing","quizzes"],"properties":{"schemaVersion":{"const":2},
            "briefing":{"type":"object","required":["summary","blocks"],"properties":{"summary":{"type":"string"},"blocks":{"type":"array","minItems":2,"maxItems":4,"items":{"type":"object","required":["type","heading","content"],"properties":{"type":{"enum":["CONCEPT","EXAMPLE","CAUTION"]},"heading":{"type":"string"},"content":{"type":"string"}}}}}},
            "quizzes":{"type":"array","minItems":%d,"maxItems":%d,"items":{"type":"object","required":["type","difficulty","questionText","hint","explanationSummary","wrongAnswerExplanation"]}}}}""";

    public static final String GENERATE = generateFor(QuizPreset.BASIC_5);

    public static final String REVIEW_WITH_BRIEFING = """
            {"type":"object","required":["reviewSummary","schemaVersion","briefing","quizzes"],"properties":{"reviewSummary":{"type":"string"},
            "schemaVersion":{"const":2},"briefing":{"type":"object","required":["summary","blocks"],"properties":{"summary":{"type":"string"},"blocks":{"type":"array","minItems":2,"maxItems":4,"items":{"type":"object","required":["type","heading","content"],"properties":{"type":{"enum":["CONCEPT","EXAMPLE","CAUTION"]},"heading":{"type":"string"},"content":{"type":"string"}}}}}},
            "quizzes":{"type":"array","minItems":1,"items":{"type":"object","required":["type","difficulty","questionText","hint"]}}}}""";

    /** 구형 IMPROVE는 문제 한 개만 검수하므로 briefing을 요구하지 않는다. */
    public static final String REVIEW = """
            {"type":"object","required":["reviewSummary","quizzes"],"properties":{"reviewSummary":{"type":"string"},
            "quizzes":{"type":"array","minItems":1,"items":{"type":"object","required":["type","difficulty","questionText","hint"]}}}}""";

    public static final String OUTLINE = """
            {"type":"object","required":["steps"],"properties":{"steps":{"type":"array","minItems":3,"maxItems":20,
            "items":{"type":"object","required":["topic","learningGoal"]}}}}""";

    private AuthoringOutputSchemas() {}

    public static String generateFor(QuizPreset preset) {
        return GENERATE_TEMPLATE.formatted(preset.quizCount(), preset.quizCount());
    }
}
