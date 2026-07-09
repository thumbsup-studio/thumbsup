package studio.thumbsup.server.quiz.generation;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.QuizType;

/**
 * 엘리스 모델로 문제 세트를 생성해 DB에 저장한다(#26). 스텝당 5문제(하2·중2·상1) 고정 구성이며,
 * 변형 출제(#18)는 지원하지 않는다 — 슬롯당 문제 1개로 고정된 현재 스키마의 전제와 일치시킨다.
 */
@Service
public class QuizGenerationService {

    private static final int EXPECTED_QUIZ_COUNT = 5;
    private static final int EXPECTED_CHOICE_COUNT = 4;
    private static final int EXPECTED_SUMMARY_LINES = 3;
    private static final Pattern MARKER_PATTERN = Pattern.compile("\\[\\[([^\\[\\]]*)]]");
    private static final List<Expected> EXPECTED_SLOTS = List.of(
            new Expected(QuizType.OX, QuizDifficulty.EASY),
            new Expected(QuizType.OX, QuizDifficulty.EASY),
            new Expected(QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM),
            new Expected(QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM),
            new Expected(QuizType.KEYWORD_BLANK, QuizDifficulty.HARD));

    private final EliceClient eliceClient;
    private final QuizRepository quizRepository;
    private final QuizStepRepository quizStepRepository;
    private final ObjectMapper objectMapper;

    public QuizGenerationService(
            EliceClient eliceClient,
            QuizRepository quizRepository,
            QuizStepRepository quizStepRepository,
            ObjectMapper objectMapper) {
        this.eliceClient = eliceClient;
        this.quizRepository = quizRepository;
        this.quizStepRepository = quizStepRepository;
        this.objectMapper = objectMapper;
    }

    /** 코스 주제로 한 스텝(5문제)을 생성·저장하고, 배정된 스텝 번호를 반환한다. */
    @Transactional
    public int generateStep(String courseTopic) {
        int stepOrder = quizRepository.findMaxStepOrder().map(max -> max + 1).orElse(1);

        String rawResponse = eliceClient.generate(QuizGenerationPromptBuilder.build(courseTopic));
        GeneratedQuizSet generated = parse(rawResponse);
        validate(generated);

        // quiz.step_order가 FK로 quiz_step.step_order를 참조하므로 반드시 먼저 저장한다.
        quizStepRepository.save(QuizStep.create(stepOrder, courseTopic));

        int slotOrder = 1;
        for (GeneratedQuizSet.GeneratedQuiz g : generated.quizzes()) {
            Quiz quiz = toEntity(g);
            quiz.assignPosition(stepOrder, slotOrder++);
            quizRepository.save(quiz);
        }
        return stepOrder;
    }

    private GeneratedQuizSet parse(String rawResponse) {
        String cleaned = stripMarkdownFence(rawResponse);
        try {
            return objectMapper.readValue(cleaned, GeneratedQuizSet.class);
        } catch (Exception e) {
            throw new QuizGenerationException("엘리스 응답을 JSON으로 파싱하지 못했습니다: " + rawResponse, e);
        }
    }

    private String stripMarkdownFence(String raw) {
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

    private void validate(GeneratedQuizSet generated) {
        List<GeneratedQuizSet.GeneratedQuiz> quizzes = generated.quizzes();
        if (quizzes == null || quizzes.size() != EXPECTED_QUIZ_COUNT) {
            throw new QuizGenerationException(
                    "생성된 문제 개수가 %d개가 아닙니다: %s".formatted(EXPECTED_QUIZ_COUNT, quizzes == null ? 0 : quizzes.size()));
        }
        for (int i = 0; i < EXPECTED_QUIZ_COUNT; i++) {
            validateSlot(i + 1, quizzes.get(i), EXPECTED_SLOTS.get(i));
        }
    }

    private void validateSlot(int slotOrder, GeneratedQuizSet.GeneratedQuiz quiz, Expected expected) {
        if (quiz.type() != expected.type() || quiz.difficulty() != expected.difficulty()) {
            throw new QuizGenerationException("슬롯 %d의 유형/난이도가 예상과 다릅니다: %s/%s (기대: %s/%s)"
                    .formatted(slotOrder, quiz.type(), quiz.difficulty(), expected.type(), expected.difficulty()));
        }
        validateCommonFields(slotOrder, quiz);
        validateTypeSpecificFields(slotOrder, quiz);
    }

    private void validateCommonFields(int slotOrder, GeneratedQuizSet.GeneratedQuiz quiz) {
        requireNonBlank(slotOrder, "questionText", quiz.questionText());
        requireNonBlank(slotOrder, "explanationSummary", quiz.explanationSummary());
        requireNonBlank(slotOrder, "wrongAnswerExplanation", quiz.wrongAnswerExplanation());
        requirePrimaryFollowUpQuestion(slotOrder, quiz.followUpQuestions());
        requireNonEmpty(slotOrder, "derivedConcepts", quiz.derivedConcepts());
        if (quiz.keywords() == null || quiz.keywords().isEmpty()) {
            throw new QuizGenerationException("슬롯 %d의 keywords가 비어 있습니다.".formatted(slotOrder));
        }
        validateExplanationSummaryLineCount(slotOrder, quiz.explanationSummary());
        validateKeywordMarkers(slotOrder, quiz);
    }

    /** explanationSummary는 #43(해설 조회 API)의 "핵심 3줄" 계약이라 정확히 3줄이어야 한다. */
    private void validateExplanationSummaryLineCount(int slotOrder, String explanationSummary) {
        String[] lines = explanationSummary.split("\n", -1);
        boolean hasBlankLine = Arrays.stream(lines).anyMatch(String::isBlank);
        if (lines.length != EXPECTED_SUMMARY_LINES || hasBlankLine) {
            throw new QuizGenerationException("슬롯 %d의 explanationSummary가 정확히 %d줄이 아닙니다(실제 %d줄)."
                    .formatted(slotOrder, EXPECTED_SUMMARY_LINES, lines.length));
        }
    }

    /**
     * #43(해설 조회 API)이 해설 본문에서 키워드 위치를 찾을 수 있도록, 생성 시점에 [[키워드]] 마커를 심는다.
     * keywords에 등록된 모든 용어가 explanationSummary·explanationExample·wrongAnswerExplanation 중
     * 최소 한 곳에 마킹돼 있어야 하고, 마커 문자열은 오타 없이 keywords와 정확히 일치해야 한다.
     */
    private void validateKeywordMarkers(int slotOrder, GeneratedQuizSet.GeneratedQuiz quiz) {
        Set<String> registeredKeywords = quiz.keywords().stream()
                .map(GeneratedQuizSet.GeneratedKeyword::keyword)
                .collect(Collectors.toSet());

        Set<String> coveredKeywords = new HashSet<>();
        coveredKeywords.addAll(
                validateMarkersInField(slotOrder, "explanationSummary", quiz.explanationSummary(), registeredKeywords));
        coveredKeywords.addAll(
                validateMarkersInField(slotOrder, "explanationExample", quiz.explanationExample(), registeredKeywords));
        coveredKeywords.addAll(validateMarkersInField(
                slotOrder, "wrongAnswerExplanation", quiz.wrongAnswerExplanation(), registeredKeywords));

        Set<String> uncovered = new HashSet<>(registeredKeywords);
        uncovered.removeAll(coveredKeywords);
        if (!uncovered.isEmpty()) {
            throw new QuizGenerationException(
                    "슬롯 %d의 키워드가 해설 3개 컬럼 어디에도 마킹되지 않았습니다: %s".formatted(slotOrder, uncovered));
        }
    }

    private Set<String> validateMarkersInField(
            int slotOrder, String field, String text, Set<String> registeredKeywords) {
        List<String> markers = extractMarkers(slotOrder, field, text);
        Set<String> seenInField = new HashSet<>();
        for (String marker : markers) {
            if (!registeredKeywords.contains(marker)) {
                throw new QuizGenerationException(
                        "슬롯 %d의 %s에 keywords에 없는 마커가 있습니다(오타 의심): [[%s]]".formatted(slotOrder, field, marker));
            }
            if (!seenInField.add(marker)) {
                throw new QuizGenerationException(
                        "슬롯 %d의 %s에서 같은 키워드가 두 번 이상 마킹됐습니다(첫 등장만 허용): [[%s]]".formatted(slotOrder, field, marker));
            }
        }
        return seenInField;
    }

    private List<String> extractMarkers(int slotOrder, String field, String text) {
        if (text == null) {
            return List.of();
        }
        List<String> markers = new ArrayList<>();
        Matcher matcher = MARKER_PATTERN.matcher(text);
        while (matcher.find()) {
            markers.add(matcher.group(1));
        }
        String withoutMarkers = MARKER_PATTERN.matcher(text).replaceAll("");
        if (withoutMarkers.contains("[[") || withoutMarkers.contains("]]")) {
            throw new QuizGenerationException("슬롯 %d의 %s에 마커 괄호 짝이 맞지 않습니다.".formatted(slotOrder, field));
        }
        return markers;
    }

    private void requirePrimaryFollowUpQuestion(
            int slotOrder, List<GeneratedQuizSet.GeneratedFollowUpQuestion> followUpQuestions) {
        long primaryCount = followUpQuestions == null
                ? 0
                : followUpQuestions.stream()
                        .filter(GeneratedQuizSet.GeneratedFollowUpQuestion::isPrimary)
                        .count();
        if (primaryCount != 1) {
            throw new QuizGenerationException(
                    "슬롯 %d의 followUpQuestions는 대표(isPrimary=true) 1개를 포함해야 합니다.".formatted(slotOrder));
        }
    }

    private void validateTypeSpecificFields(int slotOrder, GeneratedQuizSet.GeneratedQuiz quiz) {
        if (quiz.type() == QuizType.OX) {
            validateOxAnswer(slotOrder, quiz.correctAnswer());
        } else if (quiz.type() == QuizType.MULTIPLE_CHOICE) {
            validateChoices(slotOrder, quiz.choices());
        } else {
            validateAnswerKeywords(slotOrder, quiz.answerKeywords());
        }
    }

    /**
     * answerKeywords는 "빈칸별 동의어 묶음" 목록이다 — 바깥 리스트 원소 하나 = 빈칸 하나, 그 안의 문자열들은
     * 그 빈칸의 동의어(하나만 맞아도 정답)다. 빈칸이 비어있거나, 어떤 빈칸의 동의어 묶음이 빈 리스트면 안 된다.
     */
    private void validateAnswerKeywords(int slotOrder, List<List<String>> answerKeywords) {
        if (answerKeywords == null || answerKeywords.isEmpty()) {
            throw new QuizGenerationException("슬롯 %d의 answerKeywords가 비어 있습니다.".formatted(slotOrder));
        }
        for (List<String> synonyms : answerKeywords) {
            if (synonyms == null || synonyms.isEmpty()) {
                throw new QuizGenerationException("슬롯 %d의 answerKeywords 중 빈 동의어 묶음이 있습니다.".formatted(slotOrder));
            }
        }
    }

    private void validateOxAnswer(int slotOrder, String correctAnswer) {
        if (!"O".equals(correctAnswer) && !"X".equals(correctAnswer)) {
            throw new QuizGenerationException(
                    "슬롯 %d(OX)의 correctAnswer가 O/X가 아닙니다: %s".formatted(slotOrder, correctAnswer));
        }
    }

    private void validateChoices(int slotOrder, List<GeneratedQuizSet.GeneratedChoice> choices) {
        if (choices == null || choices.size() != EXPECTED_CHOICE_COUNT) {
            throw new QuizGenerationException(
                    "슬롯 %d(사지선다)의 choices가 %d개가 아닙니다.".formatted(slotOrder, EXPECTED_CHOICE_COUNT));
        }
        long correctCount = choices.stream()
                .filter(GeneratedQuizSet.GeneratedChoice::isCorrect)
                .count();
        if (correctCount != 1) {
            throw new QuizGenerationException(
                    "슬롯 %d(사지선다)의 정답 선택지가 정확히 1개가 아닙니다: %d개".formatted(slotOrder, correctCount));
        }
    }

    private void requireNonBlank(int slotOrder, String field, String value) {
        if (value == null || value.isBlank()) {
            throw new QuizGenerationException("슬롯 %d의 %s가 비어 있습니다.".formatted(slotOrder, field));
        }
    }

    private void requireNonEmpty(int slotOrder, String field, List<String> values) {
        if (values == null || values.isEmpty()) {
            throw new QuizGenerationException("슬롯 %d의 %s가 비어 있습니다.".formatted(slotOrder, field));
        }
    }

    private Quiz toEntity(GeneratedQuizSet.GeneratedQuiz g) {
        Quiz quiz = Quiz.create(
                g.type(),
                g.difficulty(),
                g.questionText(),
                g.codeSnippet(),
                g.explanationSummary(),
                g.explanationExample(),
                g.wrongAnswerExplanation());

        if (g.type() == QuizType.OX) {
            quiz.assignCorrectAnswer(g.correctAnswer());
        }
        if (g.type() == QuizType.MULTIPLE_CHOICE) {
            addChoices(quiz, g.choices());
        }
        if (g.type() == QuizType.KEYWORD_BLANK) {
            addAnswerKeywords(quiz, g.answerKeywords());
        }
        addFollowUpQuestions(quiz, g.followUpQuestions());
        addDerivedConcepts(quiz, g.derivedConcepts());
        g.keywords().forEach(keyword -> quiz.addKeyword(keyword.keyword(), keyword.description()));
        return quiz;
    }

    private void addChoices(Quiz quiz, List<GeneratedQuizSet.GeneratedChoice> choices) {
        int order = 1;
        for (GeneratedQuizSet.GeneratedChoice choice : choices) {
            quiz.addChoice(choice.content(), choice.isCorrect(), order++);
        }
    }

    private void addAnswerKeywords(Quiz quiz, List<List<String>> answerKeywords) {
        int slot = 1;
        for (List<String> synonyms : answerKeywords) {
            for (String keyword : synonyms) {
                quiz.addAnswerKeyword(slot, keyword);
            }
            slot++;
        }
    }

    private void addFollowUpQuestions(Quiz quiz, List<GeneratedQuizSet.GeneratedFollowUpQuestion> followUpQuestions) {
        int order = 1;
        for (GeneratedQuizSet.GeneratedFollowUpQuestion fq : followUpQuestions) {
            quiz.addFollowUpQuestion(fq.content(), fq.isPrimary(), order++);
        }
    }

    private void addDerivedConcepts(Quiz quiz, List<String> derivedConcepts) {
        int order = 1;
        for (String concept : derivedConcepts) {
            quiz.addDerivedConcept(concept, order++);
        }
    }

    private record Expected(QuizType type, QuizDifficulty difficulty) {}
}
