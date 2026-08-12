package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.persistence.EntityManager;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.sql.DataSource;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import studio.thumbsup.server.common.support.RepositoryTestSupport;

class QuizExplanationMarkerMigrationTest extends RepositoryTestSupport {

    private static final Pattern HIGHLIGHT_MARKER_PATTERN = Pattern.compile("\\[\\[([^\\[\\]]+)\\]\\]");
    private static final String MIGRATION_PATH =
            "db/migration/V20260711110000__dedupe_explanation_highlight_markers.sql";

    private final QuizRepository quizRepository;
    private final QuizStepRepository quizStepRepository;
    private final EntityManager entityManager;
    private final DataSource dataSource;

    QuizExplanationMarkerMigrationTest(
            @Autowired QuizRepository quizRepository,
            @Autowired QuizStepRepository quizStepRepository,
            @Autowired EntityManager entityManager,
            @Autowired DataSource dataSource) {
        this.quizRepository = quizRepository;
        this.quizStepRepository = quizStepRepository;
        this.entityManager = entityManager;
        this.dataSource = dataSource;
    }

    @Test
    @DisplayName("시드된 모든 해설은 등록 키워드만 한 번씩 마킹하고 구분자가 짝을 이룬다")
    void marks_each_seeded_keyword_once_across_all_explanation_fields() {
        List<String> violations = new ArrayList<>();

        for (Quiz quiz : quizRepository.findAll()) {
            String position = "step=" + quiz.getStepOrder() + ", slot=" + quiz.getSlotOrder();
            Set<String> registeredKeywords = new HashSet<>();
            quiz.getKeywords().forEach(keyword -> registeredKeywords.add(keyword.getKeyword()));

            Map<String, Integer> markerCounts = new HashMap<>();
            for (String text : explanationTexts(quiz)) {
                collectMarkerViolations(position, text, registeredKeywords, markerCounts, violations);
            }

            for (String registeredKeyword : registeredKeywords) {
                int markerCount = markerCounts.getOrDefault(registeredKeyword, 0);
                if (markerCount != 1) {
                    violations.add(position + ": " + registeredKeyword + " 마커 " + markerCount + "회");
                }
            }
        }

        assertThat(violations).as("해설 마커 전수 검사 위반 목록").isEmpty();
    }

    @Test
    @DisplayName("대소문자가 다른 미등록 마커를 등록 마커로 오인하지 않는다")
    void matches_registered_markers_with_exact_binary_collation() {
        Quiz quiz = saveQuiz(14701, "상위 [[pcb]] 미등록", null, "하위 [[PCB]] 등록", false);

        rerunMigration();

        Quiz rewritten = reload(quiz);
        assertThat(rewritten.getExplanationSummary()).isEqualTo("상위 [[pcb]] 미등록");
        assertThat(rewritten.getWrongAnswerExplanation()).isEqualTo("하위 [[PCB]] 등록");
    }

    @Test
    @DisplayName("첫 등록 마커만 남기고 같은 필드와 하위 필드의 구분자만 제거한다")
    void keeps_first_marker_and_preserves_visible_text() {
        String summary = "앞 [[PCB]] 중간 [[PCB]] 뒤";
        String wrongAnswer = "오답 [[PCB]] 설명";
        Quiz quiz = saveQuiz(14702, summary, null, wrongAnswer, true);

        rerunMigration();

        Quiz rewritten = reload(quiz);
        assertThat(rewritten.getExplanationSummary()).isEqualTo("앞 [[PCB]] 중간 PCB 뒤");
        assertThat(rewritten.getExplanationExample()).isNull();
        assertThat(rewritten.getWrongAnswerExplanation()).isEqualTo("오답 PCB 설명");
        assertThat(stripMarkers(rewritten.getExplanationSummary())).isEqualTo(stripMarkers(summary));
        assertThat(stripMarkers(rewritten.getWrongAnswerExplanation())).isEqualTo(stripMarkers(wrongAnswer));
    }

    private Quiz saveQuiz(
            int stepOrder, String summary, String example, String wrongAnswer, boolean duplicateKeywordRow) {
        quizStepRepository.save(QuizStep.create(stepOrder, 1L, "마이그레이션 테스트", 5));
        Quiz quiz = Quiz.create(QuizType.OX, QuizDifficulty.EASY, "테스트 문제", null, summary, example, wrongAnswer);
        quiz.assignHint("판단에 필요한 조건을 떠올려 보세요.");
        quiz.assignCorrectAnswer("O");
        quiz.assignPosition(stepOrder, 1);
        quiz.addKeyword("PCB", "프로세스 제어 블록");
        if (duplicateKeywordRow) {
            quiz.addKeyword("PCB", "중복 사전 행");
        }
        return quizRepository.saveAndFlush(quiz);
    }

    private void rerunMigration() {
        ResourceDatabasePopulator populator = new ResourceDatabasePopulator(new ClassPathResource(MIGRATION_PATH));
        populator.execute(dataSource);
        entityManager.clear();
    }

    private Quiz reload(Quiz quiz) {
        return quizRepository.findById(quiz.getId()).orElseThrow();
    }

    private String stripMarkers(String text) {
        return text.replace("[[", "").replace("]]", "");
    }

    private List<String> explanationTexts(Quiz quiz) {
        List<String> texts = new ArrayList<>();
        texts.add(quiz.getExplanationSummary());
        if (quiz.getExplanationExample() != null) {
            texts.add(quiz.getExplanationExample());
        }
        texts.add(quiz.getWrongAnswerExplanation());
        return texts;
    }

    private void collectMarkerViolations(
            String position,
            String text,
            Set<String> registeredKeywords,
            Map<String, Integer> markerCounts,
            List<String> violations) {
        Matcher matcher = HIGHLIGHT_MARKER_PATTERN.matcher(text);
        while (matcher.find()) {
            String markedKeyword = matcher.group(1);
            markerCounts.merge(markedKeyword, 1, Integer::sum);
            if (!registeredKeywords.contains(markedKeyword)) {
                violations.add(position + ": 미등록 마커 " + markedKeyword);
            }
        }

        String textWithoutCompleteMarkers =
                HIGHLIGHT_MARKER_PATTERN.matcher(text).replaceAll("");
        if (textWithoutCompleteMarkers.contains("[[") || textWithoutCompleteMarkers.contains("]]")) {
            violations.add(position + ": 짝이 맞지 않는 마커 구분자");
        }
    }
}
