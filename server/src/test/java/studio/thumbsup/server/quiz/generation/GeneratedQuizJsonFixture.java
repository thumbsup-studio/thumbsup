package studio.thumbsup.server.quiz.generation;

/**
 * 엘리스 응답을 흉내 낸 JSON 조각. 검증기는 파싱된 객체가 아니라 "모델이 실제로 뱉는 문자열"을 통과해야 하므로
 * 픽스처도 JSON으로 둔다.
 *
 * <p>부모 문제의 사전은 {@code PCB}, 꼬리질문의 사전은 {@code FIFO}로 일부러 갈라 놓았다 — 둘을 섞어 쓰면
 * 검증기가 오타로 잡아야 한다는 것이 이 픽스처가 지키는 계약이다(#133).
 */
final class GeneratedQuizJsonFixture {

    static final String DEFAULT_BLOCKS = "[{\"label\": \"해설\", \"content\": \"큐는 먼저 넣은 것이 먼저 나온다.\"}]";
    static final String DEFAULT_KEYWORDS = "[{\"keyword\": \"FIFO\", \"description\": \"설명\"}]";
    static final String DEFAULT_ONE_LINE_ANSWER = "[[FIFO]]는 먼저 넣은 것이 먼저 나온다.";

    private GeneratedQuizJsonFixture() {}

    /** difficultyLiteral은 JSON 리터럴 그대로 넣는다 — {@code "\"MEDIUM\""} 또는 {@code "null"}. */
    static String followUpJson(
            String content, String difficultyLiteral, String oneLineAnswer, String blocks, String keywords) {
        return """
                {
                  "content": "%s",
                  "isPrimary": true,
                  "difficulty": %s,
                  "oneLineAnswer": "%s",
                  "blocks": %s,
                  "keywords": %s
                }
                """.formatted(content, difficultyLiteral, oneLineAnswer, blocks, keywords);
    }

    static String defaultFollowUpJson() {
        return followUpJson("꼬리질문", "\"MEDIUM\"", DEFAULT_ONE_LINE_ANSWER, DEFAULT_BLOCKS, DEFAULT_KEYWORDS);
    }

    static String quizJson(String type, String difficulty, String questionText, String extraFields) {
        return quizJson(type, difficulty, questionText, extraFields, defaultFollowUpJson());
    }

    static String quizJson(
            String type, String difficulty, String questionText, String extraFields, String followUpQuestions) {
        return """
                {
                  "type": "%s",
                  "difficulty": "%s",
                  "questionText": "%s",
                  "codeSnippet": null,
                  "explanationSummary": "[[PCB]]는 핵심 요약 1줄.\\n핵심 요약 2줄.\\n핵심 요약 3줄.",
                  "explanationExample": null,
                  "wrongAnswerExplanation": "오답 해설",
                  %s,
                  "followUpQuestions": [%s],
                  "derivedConcepts": ["개념1"],
                  "keywords": [{"keyword": "PCB", "description": "설명"}]
                }
                """.formatted(type, difficulty, questionText, extraFields, followUpQuestions);
    }

    static String oxQuizJson() {
        return quizJson("OX", "EASY", "질문 본문", "\"correctAnswer\": \"O\", \"choices\": null, \"answerKeywords\": null");
    }

    /** 꼬리질문만 갈아끼운 OX 문제 — 꼬리질문 검증 테스트가 첫 슬롯에 꽂아 쓴다. */
    static String oxQuizJsonWith(String followUpQuestions) {
        return quizJson(
                "OX",
                "EASY",
                "질문 본문",
                "\"correctAnswer\": \"O\", \"choices\": null, \"answerKeywords\": null",
                followUpQuestions);
    }

    static String multipleChoiceQuizJson() {
        return quizJson("MULTIPLE_CHOICE", "MEDIUM", "질문 본문", """
                "correctAnswer": null, "answerKeywords": null,
                "choices": [
                  {"content": "a", "isCorrect": false},
                  {"content": "b", "isCorrect": true},
                  {"content": "c", "isCorrect": false},
                  {"content": "d", "isCorrect": false}
                ]
                """);
    }

    static String keywordBlankQuizJson() {
        return quizJson(
                "KEYWORD_BLANK",
                "HARD",
                "빈칸 ___ 채우기 문제",
                "\"correctAnswer\": null, \"choices\": null, \"answerKeywords\": [[\"LIFO\", \"Last In First Out\"]]");
    }

    static String validSetJson() {
        return setJsonWithFirstQuiz(oxQuizJson());
    }

    /** 첫 슬롯만 바꿔 끼운 5문제 세트 — 나머지 네 문제는 항상 유효하므로 검증 실패의 원인이 첫 문제로 좁혀진다. */
    static String setJsonWithFirstQuiz(String firstQuizJson) {
        return "{\"quizzes\": [%s, %s, %s, %s, %s]}"
                .formatted(
                        firstQuizJson,
                        oxQuizJson(),
                        multipleChoiceQuizJson(),
                        multipleChoiceQuizJson(),
                        keywordBlankQuizJson());
    }
}
