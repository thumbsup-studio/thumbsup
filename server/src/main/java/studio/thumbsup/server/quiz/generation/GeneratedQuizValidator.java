package studio.thumbsup.server.quiz.generation;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import org.springframework.stereotype.Component;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizType;

/**
 * 엘리스 응답 문자열을 파싱하고, 생성된 문제가 저장 가능한 형태인지 검증한다. {@link QuizGenerationService}에서
 * 분리한 이유는 저작 파이프라인(#174)의 REVIEW/IMPROVE 잡도 같은 검증 규칙을 재사용해야 하기 때문이다 —
 * {@link #validateSet}은 스텝 생성(5슬롯 고정 구성), {@link #validateSingle}은 검수·개선 단건에 쓴다.
 */
@Component
public class GeneratedQuizValidator {

    private static final int EXPECTED_QUIZ_COUNT = 5;
    private static final int EXPECTED_CHOICE_COUNT = 4;
    private static final int EXPECTED_SUMMARY_LINES = 3;
    /** 첫 블록만 고정한다 — 그 뒤 블록의 개수·라벨은 문제 성격에 맞게 모델이 정한다(#133 팀 결정). */
    private static final String FIRST_BLOCK_LABEL = "해설";

    private static final List<Expected> EXPECTED_SLOTS = List.of(
            new Expected(QuizType.OX, QuizDifficulty.EASY),
            new Expected(QuizType.OX, QuizDifficulty.EASY),
            new Expected(QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM),
            new Expected(QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM),
            new Expected(QuizType.KEYWORD_BLANK, QuizDifficulty.HARD));

    private final ObjectMapper objectMapper;

    public GeneratedQuizValidator(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public GeneratedQuizSet parse(String rawResponse) {
        String cleaned = stripMarkdownFence(rawResponse);
        try {
            return objectMapper.readValue(cleaned, GeneratedQuizSet.class);
        } catch (Exception e) {
            throw new QuizGenerationException("엘리스 응답을 JSON으로 파싱하지 못했습니다: " + rawResponse, e);
        }
    }

    /** 코드펜스 제거만 필요한 호출자(REVIEW 결과의 {@code ReviewResult} 역직렬화 등)를 위해 공개한다. */
    public String stripMarkdownFence(String raw) {
        String trimmed = raw.trim();
        if (!trimmed.startsWith("```")) {
            return trimmed;
        }
        trimmed = trimmed.replaceFirst("^```[a-zA-Z]*\\n", "").trim();
        if (trimmed.endsWith("```")) {
            trimmed = trimmed.substring(0, trimmed.length() - 3).trim();
        }
        return trimmed;
    }

    public void validateSet(GeneratedQuizSet generated) {
        List<GeneratedQuizSet.GeneratedQuiz> quizzes = generated.quizzes();
        if (quizzes == null || quizzes.size() != EXPECTED_QUIZ_COUNT) {
            throw new QuizGenerationException(
                    "생성된 문제 개수가 %d개가 아닙니다: %s".formatted(EXPECTED_QUIZ_COUNT, quizzes == null ? 0 : quizzes.size()));
        }
        for (int i = 0; i < EXPECTED_QUIZ_COUNT; i++) {
            Expected expected = EXPECTED_SLOTS.get(i);
            validateSlot("슬롯 %d".formatted(i + 1), quizzes.get(i), expected.type(), expected.difficulty());
        }
    }

    public void validateSingle(
            GeneratedQuizSet.GeneratedQuiz quiz, QuizType expectedType, QuizDifficulty expectedDifficulty) {
        validateSlot("문제", quiz, expectedType, expectedDifficulty);
    }

    private void validateSlot(
            String location,
            GeneratedQuizSet.GeneratedQuiz quiz,
            QuizType expectedType,
            QuizDifficulty expectedDifficulty) {
        if (quiz.type() != expectedType || quiz.difficulty() != expectedDifficulty) {
            throw new QuizGenerationException("%s의 유형/난이도가 예상과 다릅니다: %s/%s (기대: %s/%s)"
                    .formatted(location, quiz.type(), quiz.difficulty(), expectedType, expectedDifficulty));
        }
        validateCommonFields(location, quiz);
        validateTypeSpecificFields(location, quiz);
    }

    private void validateCommonFields(String location, GeneratedQuizSet.GeneratedQuiz quiz) {
        requireNonBlank(location, "questionText", quiz.questionText());
        CodeSnippetValidator.validate(location, quiz.codeSnippet());
        requireNonBlank(location, "explanationSummary", quiz.explanationSummary());
        requireNonBlank(location, "wrongAnswerExplanation", quiz.wrongAnswerExplanation());
        requireNonEmpty(location, "derivedConcepts", quiz.derivedConcepts());
        validateKeywords(location, quiz.keywords());
        validateExplanationSummaryLineCount(location, quiz.explanationSummary());
        validateKeywordMarkers(location, quiz);
        validateFollowUpQuestions(location, quiz.followUpQuestions());
    }

    /** explanationSummary는 #43(해설 조회 API)의 "핵심 3줄, 줄 끝 공백 없음" 계약이라 이를 엄격히 검증한다. */
    private void validateExplanationSummaryLineCount(String location, String explanationSummary) {
        String[] lines = explanationSummary.split("\n", -1);
        boolean hasBlankLine = Arrays.stream(lines).anyMatch(String::isBlank);
        boolean hasTrailingWhitespace = Arrays.stream(lines).anyMatch(line -> !line.equals(line.stripTrailing()));
        if (lines.length != EXPECTED_SUMMARY_LINES || hasBlankLine || hasTrailingWhitespace) {
            throw new QuizGenerationException("%s의 explanationSummary가 정확히 %d줄이 아닙니다(실제 %d줄)."
                    .formatted(location, EXPECTED_SUMMARY_LINES, lines.length));
        }
    }

    /**
     * #43(해설 조회 API)이 해설 본문에서 키워드 위치를 찾을 수 있도록, 생성 시점에 [[키워드]] 마커를 심는다.
     * keywords에 등록된 모든 용어가 explanationSummary·explanationExample·wrongAnswerExplanation 전체에서
     * 정확히 한 번 마킹돼 있어야 하고, 마커 문자열은 오타 없이 keywords와 정확히 일치해야 한다.
     */
    private void validateKeywordMarkers(String location, GeneratedQuizSet.GeneratedQuiz quiz) {
        Set<String> registeredKeywords = quiz.keywords().stream()
                .map(GeneratedQuizSet.GeneratedKeyword::keyword)
                .collect(Collectors.toSet());

        Set<String> coveredKeywords = new HashSet<>();
        validateFieldAcrossScope(
                location,
                "explanationSummary",
                quiz.explanationSummary(),
                registeredKeywords,
                coveredKeywords,
                "해설 3개 컬럼");
        validateFieldAcrossScope(
                location,
                "explanationExample",
                quiz.explanationExample(),
                registeredKeywords,
                coveredKeywords,
                "해설 3개 컬럼");
        validateFieldAcrossScope(
                location,
                "wrongAnswerExplanation",
                quiz.wrongAnswerExplanation(),
                registeredKeywords,
                coveredKeywords,
                "해설 3개 컬럼");

        KeywordMarkerValidator.requireAllCovered(location, registeredKeywords, coveredKeywords, "해설 3개 컬럼");
    }

    /**
     * 꼬리질문은 상세(난이도·한 줄 답·블록·키워드)를 함께 갖춰야 한다(#133) — 하나라도 비면 조회 API가
     * 그 꼬리질문을 응답에서 감춰버리므로, 저장 전에 여기서 막지 않으면 조용히 사라진다.
     */
    private void validateFollowUpQuestions(
            String location, List<GeneratedQuizSet.GeneratedFollowUpQuestion> followUpQuestions) {
        requirePrimaryFollowUpQuestion(location, followUpQuestions);
        int index = 1;
        for (GeneratedQuizSet.GeneratedFollowUpQuestion followUpQuestion : followUpQuestions) {
            validateFollowUpQuestion("%s의 꼬리질문 %d".formatted(location, index++), followUpQuestion);
        }
    }

    private void validateFollowUpQuestion(
            String location, GeneratedQuizSet.GeneratedFollowUpQuestion followUpQuestion) {
        requireNonBlank(location, "content", followUpQuestion.content());
        // 질문 본문은 서버가 평문으로 그대로 내려준다 — 마커가 섞이면 화면에 [[ ]]가 그대로 보인다.
        KeywordMarkerValidator.requireNoMarker(location, "content", followUpQuestion.content());
        requireNonBlank(location, "oneLineAnswer", followUpQuestion.oneLineAnswer());
        if (followUpQuestion.difficulty() == null) {
            throw new QuizGenerationException("%s의 difficulty가 비어 있습니다.".formatted(location));
        }
        validateKeywords(location, followUpQuestion.keywords());
        validateFollowUpBlocks(location, followUpQuestion.blocks());
        validateFollowUpMarkers(location, followUpQuestion);
    }

    private void validateFollowUpBlocks(String location, List<GeneratedQuizSet.GeneratedFollowUpBlock> blocks) {
        if (blocks == null || blocks.isEmpty()) {
            throw new QuizGenerationException("%s의 blocks가 비어 있습니다.".formatted(location));
        }
        if (!FIRST_BLOCK_LABEL.equals(blocks.get(0).label())) {
            throw new QuizGenerationException("%s의 첫 블록 label은 \"%s\"여야 합니다: %s"
                    .formatted(location, FIRST_BLOCK_LABEL, blocks.get(0).label()));
        }
        int index = 1;
        for (GeneratedQuizSet.GeneratedFollowUpBlock block : blocks) {
            requireNonBlank(location, "blocks[%d].label".formatted(index), block.label());
            requireNonBlank(location, "blocks[%d].content".formatted(index), block.content());
            index++;
        }
    }

    /**
     * 사전과 마커 범위는 꼬리질문마다 독립적이다 — 부모 문제의 keywords를 쓰지 않고, 한 줄 답과 모든 블록
     * 전체에서 등록 키워드마다 정확히 한 번만 허용한다. 블록 배열 순서는 저장될 displayOrder 순서다.
     */
    private void validateFollowUpMarkers(String location, GeneratedQuizSet.GeneratedFollowUpQuestion followUpQuestion) {
        Set<String> registeredKeywords = followUpQuestion.keywords().stream()
                .map(GeneratedQuizSet.GeneratedKeyword::keyword)
                .collect(Collectors.toSet());

        Set<String> coveredKeywords = new HashSet<>();
        validateFieldAcrossScope(
                location,
                "oneLineAnswer",
                followUpQuestion.oneLineAnswer(),
                registeredKeywords,
                coveredKeywords,
                "한 줄 답과 상세 정리 블록");
        int index = 1;
        for (GeneratedQuizSet.GeneratedFollowUpBlock block : followUpQuestion.blocks()) {
            validateFieldAcrossScope(
                    location,
                    "blocks[%d].content".formatted(index++),
                    block.content(),
                    registeredKeywords,
                    coveredKeywords,
                    "한 줄 답과 상세 정리 블록");
        }

        KeywordMarkerValidator.requireAllCovered(location, registeredKeywords, coveredKeywords, "한 줄 답과 상세 정리 블록");
    }

    private void validateFieldAcrossScope(
            String location,
            String field,
            String text,
            Set<String> registeredKeywords,
            Set<String> coveredKeywords,
            String scopeLabel) {
        Set<String> fieldKeywords = KeywordMarkerValidator.validateField(location, field, text, registeredKeywords);
        Set<String> duplicatedKeywords = new HashSet<>(coveredKeywords);
        duplicatedKeywords.retainAll(fieldKeywords);
        if (!duplicatedKeywords.isEmpty()) {
            String duplicatedMarkers = duplicatedKeywords.stream()
                    .sorted()
                    .map(keyword -> "[[%s]]".formatted(keyword))
                    .collect(Collectors.joining(", "));
            throw new QuizGenerationException(
                    "%s의 %s에서 같은 키워드가 두 번 이상 마킹됐습니다: %s".formatted(location, scopeLabel, duplicatedMarkers));
        }
        coveredKeywords.addAll(fieldKeywords);
    }

    private void requirePrimaryFollowUpQuestion(
            String location, List<GeneratedQuizSet.GeneratedFollowUpQuestion> followUpQuestions) {
        long primaryCount = followUpQuestions == null
                ? 0
                : followUpQuestions.stream()
                        .filter(GeneratedQuizSet.GeneratedFollowUpQuestion::isPrimary)
                        .count();
        if (primaryCount != 1) {
            throw new QuizGenerationException(
                    "%s의 followUpQuestions는 대표(isPrimary=true) 1개를 포함해야 합니다.".formatted(location));
        }
    }

    private void validateTypeSpecificFields(String location, GeneratedQuizSet.GeneratedQuiz quiz) {
        if (quiz.type() == QuizType.OX) {
            validateOxAnswer(location, quiz.correctAnswer());
        } else if (quiz.type() == QuizType.MULTIPLE_CHOICE) {
            validateChoices(location, quiz.choices());
        } else {
            validateAnswerKeywords(location, quiz.questionText(), quiz.answerKeywords());
        }
    }

    /**
     * answerKeywords는 "빈칸별 동의어 묶음" 목록이다 — 바깥 리스트 원소 하나 = 빈칸 하나, 그 안의 문자열들은
     * 그 빈칸의 동의어(하나만 맞아도 정답)다. 빈칸이 비어있거나, 어떤 빈칸의 동의어 묶음이 빈 리스트면 안 되고,
     * 배열 길이가 questionText의 실제 빈칸(___) 개수와도 일치해야 한다 — 어긋나면 QuizService의 슬롯 순서
     * 기반 채점과 실제 빈칸 위치가 틀어진다.
     */
    private void validateAnswerKeywords(String location, String questionText, List<List<String>> answerKeywords) {
        if (answerKeywords == null || answerKeywords.isEmpty()) {
            throw new QuizGenerationException("%s의 answerKeywords가 비어 있습니다.".formatted(location));
        }
        for (List<String> synonyms : answerKeywords) {
            if (synonyms == null || synonyms.isEmpty()) {
                throw new QuizGenerationException("%s의 answerKeywords 중 빈 동의어 묶음이 있습니다.".formatted(location));
            }
        }
        long blankCount = Pattern.compile("___").matcher(questionText).results().count();
        if (blankCount != answerKeywords.size()) {
            throw new QuizGenerationException("%s의 빈칸 개수(%d)와 answerKeywords 길이(%d)가 다릅니다."
                    .formatted(location, blankCount, answerKeywords.size()));
        }
    }

    private void validateOxAnswer(String location, String correctAnswer) {
        if (!"O".equals(correctAnswer) && !"X".equals(correctAnswer)) {
            throw new QuizGenerationException(
                    "%s(OX)의 correctAnswer가 O/X가 아닙니다: %s".formatted(location, correctAnswer));
        }
    }

    private void validateChoices(String location, List<GeneratedQuizSet.GeneratedChoice> choices) {
        if (choices == null || choices.size() != EXPECTED_CHOICE_COUNT) {
            throw new QuizGenerationException(
                    "%s(사지선다)의 choices가 %d개가 아닙니다.".formatted(location, EXPECTED_CHOICE_COUNT));
        }
        long correctCount = choices.stream()
                .filter(GeneratedQuizSet.GeneratedChoice::isCorrect)
                .count();
        if (correctCount != 1) {
            throw new QuizGenerationException("%s(사지선다)의 정답 선택지가 정확히 1개가 아닙니다: %d개".formatted(location, correctCount));
        }
    }

    private void validateKeywords(String location, List<GeneratedQuizSet.GeneratedKeyword> keywords) {
        if (keywords == null || keywords.isEmpty()) {
            throw new QuizGenerationException("%s의 keywords가 비어 있습니다.".formatted(location));
        }
        for (int index = 0; index < keywords.size(); index++) {
            GeneratedQuizSet.GeneratedKeyword keyword = keywords.get(index);
            if (keyword == null) {
                throw new QuizGenerationException("%s의 keywords[%d]가 비어 있습니다.".formatted(location, index + 1));
            }
            requireNonBlank(location, "keywords[%d].keyword".formatted(index + 1), keyword.keyword());
        }
    }

    private void requireNonBlank(String location, String field, String value) {
        if (value == null || value.isBlank()) {
            throw new QuizGenerationException("%s의 %s가 비어 있습니다.".formatted(location, field));
        }
    }

    private void requireNonEmpty(String location, String field, List<String> values) {
        if (values == null || values.isEmpty()) {
            throw new QuizGenerationException("%s의 %s가 비어 있습니다.".formatted(location, field));
        }
    }

    private record Expected(QuizType type, QuizDifficulty difficulty) {}
}
