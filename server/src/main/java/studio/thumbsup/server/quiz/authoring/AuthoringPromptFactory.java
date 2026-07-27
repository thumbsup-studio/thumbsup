package studio.thumbsup.server.quiz.authoring;

import java.util.List;
import java.util.stream.Collectors;
import studio.thumbsup.server.quiz.generation.QuizGenerationPromptBuilder;

/**
 * 저작 파이프라인(#174)이 브리지에 보낼 프롬프트를 조립한다. GENERATE 잡은 기존 생성 파이프라인의
 * 프롬프트({@link QuizGenerationPromptBuilder#SYSTEM_PROMPT} + {@link QuizGenerationPromptBuilder})를 그대로
 * 재사용하고, REVIEW 잡은 기존 문제를 비평·수정하는 별도 템플릿을 쓴다.
 */
public final class AuthoringPromptFactory {

    private static final String REVIEW_TEMPLATE = """
            %s

            너는 위 규칙을 따르는 검수자다. 아래 기존 문제를 비평하고, 개선한 수정본을 만들어라.

            [주제] %s

            [현재 문제 JSON]
            %s

            [검수 규칙]
            - 각 문제의 type과 difficulty는 절대 변경하지 않는다. 문제 개수도 변경하지 않는다.
            - 사실 오류, 모호한 표현, 빈약한 해설, 어색한 선지를 우선적으로 고친다.
            - hint도 반드시 검수한다. 200자 이내의 개행 없는 한 문장이어야 하며, 정답·선택지 라벨·OX 판단 결론·
              빈칸 정답 키워드나 동의어를 직접 말하지 않고 판단 단서만 제공해야 한다.
            - 원문이 이미 충분히 좋으면 최소 수정만 한다.
            %s%s
            [출력 형식]
            다음 형태의 JSON 객체 하나만 출력한다. 코드펜스·설명·인사말을 붙이지 않는다.
            {"reviewSummary": "무엇을 왜 바꿨는지 3문장 이내", "quizzes": [현재 문제 JSON과 동일한 스키마의 수정본 배열]}
            """;

    private static final String FEEDBACK_SECTION = """

            [검수자 피드백 — 반드시 반영하라]
            %s
            """;

    private static final String SIBLING_QUESTIONS_SECTION = """

            [같은 스텝의 다른 문제들 — 아래와 개념이 중복되지 않게 하라 (읽기 전용 맥락)]
            %s
            """;

    private AuthoringPromptFactory() {}

    public static String generatePrompt(String topic) {
        return QuizGenerationPromptBuilder.SYSTEM_PROMPT + "\n\n" + QuizGenerationPromptBuilder.build(topic);
    }

    public static String reviewPrompt(
            String topic, String currentPayloadJson, String feedback, List<String> siblingQuestions) {
        return REVIEW_TEMPLATE.formatted(
                QuizGenerationPromptBuilder.SYSTEM_PROMPT,
                topic,
                currentPayloadJson,
                feedbackSection(feedback),
                siblingQuestionsSection(siblingQuestions));
    }

    private static String feedbackSection(String feedback) {
        if (feedback == null || feedback.isBlank()) {
            return "";
        }
        return FEEDBACK_SECTION.formatted(feedback);
    }

    private static String siblingQuestionsSection(List<String> siblingQuestions) {
        if (siblingQuestions == null || siblingQuestions.isEmpty()) {
            return "";
        }
        String bulletList =
                siblingQuestions.stream().map(question -> "- " + question).collect(Collectors.joining("\n"));
        return SIBLING_QUESTIONS_SECTION.formatted(bulletList);
    }
}
