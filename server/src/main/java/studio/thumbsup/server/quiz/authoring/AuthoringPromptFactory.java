package studio.thumbsup.server.quiz.authoring;

import java.util.List;
import java.util.stream.Collectors;
import studio.thumbsup.server.quiz.generation.QuizGenerationPromptBuilder;
import studio.thumbsup.server.quiz.generation.QuizPreset;

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

    private static final String OUTLINE_TEMPLATE = """
            너는 목차를 학습자가 순서대로 소화할 수 있는 코스 뼈대로 재구성하는 교육과정 설계자다.

            [코스 제목] %s
            [카테고리] %s

            [목차 원문]
            %s

            [재구성 규칙]
            - 책 목차와 학습 스텝은 다르다. 장을 그대로 복사하지 말고, 학습 목표에 맞게 장을 통합하거나 분할하라.
            - 선수 개념을 먼저 배치하도록 학습 순서로 재배열하라.
            - 학습 스텝 하나가 한 번에 소화 가능한 크기가 되게 하라.
            - 스텝 수는 목차 분량에 맞춰 최소 3개, 최대 20개로 제한하라.
            - 각 스텝의 topic은 30자 이내의 짧은 주제명으로, learningGoal은 한 문장으로 작성하라.

            [출력 형식]
            설명이나 마크다운 코드펜스 없이 다음 JSON 객체 하나만 출력하라.
            {"steps":[{"topic":"스텝 주제(30자 이내)","learningGoal":"이 스텝에서 달성할 학습 목표 한 문장"}]}
            """;

    private AuthoringPromptFactory() {}

    public static String generatePrompt(String topic) {
        return QuizGenerationPromptBuilder.SYSTEM_PROMPT + "\n\n" + QuizGenerationPromptBuilder.build(topic);
    }

    public static String generatePrompt(OutlineStepContext context, QuizPreset preset) {
        return QuizGenerationPromptBuilder.SYSTEM_PROMPT
                + "\n\n"
                + outlineStepContextSection(context)
                + "\n"
                + QuizGenerationPromptBuilder.build(context.topic(), preset);
    }

    public static String outlinePrompt(String courseTitle, String category, String toc) {
        return OUTLINE_TEMPLATE.formatted(courseTitle, category, toc);
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

    private static String outlineStepContextSection(OutlineStepContext context) {
        StringBuilder section = new StringBuilder()
                .append("[코스] ")
                .append(context.courseTitle())
                .append('\n')
                .append("[이 스텝] ")
                .append(context.orderNo())
                .append('/')
                .append(context.totalSteps())
                .append(" — ")
                .append(context.topic())
                .append('\n')
                .append("[학습 목표] ")
                .append(context.learningGoal())
                .append('\n');

        if (hasText(context.prevTopic())) {
            section.append("[앞 스텝] ").append(context.prevTopic()).append(" — 이미 다룬 개념이다. 다시 가르치지 말고 전제로 삼아라.\n");
        }
        if (hasText(context.nextTopic())) {
            section.append("[뒤 스텝] ").append(context.nextTopic()).append(" — 나중에 다룰 개념이다. 미리 깊게 들어가지 마라.\n");
        }
        if (context.existingQuestions() != null && !context.existingQuestions().isEmpty()) {
            section.append("[같은 코스에서 이미 낸 문제들 — 개념이 겹치지 않게 하라 (읽기 전용 맥락)]\n");
            context.existingQuestions().stream()
                    .filter(AuthoringPromptFactory::hasText)
                    .forEach(question -> section.append("- ").append(question).append('\n'));
        }
        return section.toString();
    }

    private static boolean hasText(String value) {
        return value != null && !value.isBlank();
    }
}
