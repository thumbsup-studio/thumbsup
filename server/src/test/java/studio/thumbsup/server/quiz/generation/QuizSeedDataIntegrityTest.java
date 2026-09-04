package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.IntStream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import studio.thumbsup.server.common.support.RepositoryTestSupport;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizChoice;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.QuizType;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;

/**
 * 전체 Flyway 시드의 문제 유형·정답 구조·코드 지문 품질을 운영 반영 전에 고정한다.
 *
 * <p>step_order는 코스별 상대 순번이라(#292) 코스가 다르면 같은 stepOrder가 겹칠 수 있다 — 이 파일의
 * 좌표 기반 단언은 모두 courseId로 먼저 구분한 뒤 stepOrder·slotOrder를 본다.
 */
class QuizSeedDataIntegrityTest extends RepositoryTestSupport {

    private static final int TOTAL_QUIZ_COUNT = 380;
    private static final Pattern BLANK_PATTERN = Pattern.compile("___");

    private final QuizRepository quizRepository;
    private final QuizStepRepository quizStepRepository;
    private final CourseRepository courseRepository;

    QuizSeedDataIntegrityTest(
            @Autowired QuizRepository quizRepository,
            @Autowired QuizStepRepository quizStepRepository,
            @Autowired CourseRepository courseRepository) {
        this.quizRepository = quizRepository;
        this.quizStepRepository = quizStepRepository;
        this.courseRepository = courseRepository;
    }

    private Long courseIdByTitle(String title) {
        return courseRepository.findAll().stream()
                .filter(c -> c.getTitle().equals(title))
                .map(Course::getId)
                .findFirst()
                .orElseThrow();
    }

    /** quiz.getQuizStepId() → quiz_step.course_id 매핑 — REVIEWED_CODE_SNIPPETS 같은 코스별 좌표 단언에 쓴다. */
    private Map<Long, Long> courseIdByQuizId(List<Quiz> quizzes) {
        Map<Long, QuizStep> stepById =
                quizStepRepository
                        .findAllById(quizzes.stream().map(Quiz::getQuizStepId).collect(Collectors.toSet()))
                        .stream()
                        .collect(Collectors.toMap(QuizStep::getId, s -> s));
        return quizzes.stream().collect(Collectors.toMap(Quiz::getId, q -> stepById.get(q.getQuizStepId())
                .getCourseId()));
    }

    @Nested
    @DisplayName("전체 문제 유형 감사")
    class QuizTypeAudit {

        @Test
        @DisplayName("정식 커리큘럼 380문제가 정확한 슬롯 유형·난이도를 갖는다")
        void keeps_complete_slot_contract() {
            List<Quiz> quizzes = quizRepository.findAll();
            assertThat(quizzes).hasSize(TOTAL_QUIZ_COUNT);

            Long osCourseId = courseIdByTitle("운영체제");
            Long designPatternCourseId = courseIdByTitle("디자인 패턴");
            Long networkCourseId = courseIdByTitle("컴퓨터 네트워크");
            Long computerArchitectureCourseId = courseIdByTitle("컴퓨터 구조");
            Long dataStructuresCourseId = courseIdByTitle("자료구조");
            Map<Long, Long> courseIdByQuizId = courseIdByQuizId(quizzes);
            List<Quiz> osQuizzes = quizzes.stream()
                    .filter(q -> courseIdByQuizId.get(q.getId()).equals(osCourseId))
                    .toList();
            List<Quiz> designPatternQuizzes = quizzes.stream()
                    .filter(q -> courseIdByQuizId.get(q.getId()).equals(designPatternCourseId))
                    .toList();
            List<Quiz> networkQuizzes = quizzes.stream()
                    .filter(q -> courseIdByQuizId.get(q.getId()).equals(networkCourseId))
                    .toList();
            List<Quiz> computerArchitectureQuizzes = quizzes.stream()
                    .filter(q -> courseIdByQuizId.get(q.getId()).equals(computerArchitectureCourseId))
                    .toList();
            List<Quiz> dataStructuresQuizzes = quizzes.stream()
                    .filter(q -> courseIdByQuizId.get(q.getId()).equals(dataStructuresCourseId))
                    .toList();

            assertThat(osQuizzes).hasSize(60);
            assertThat(designPatternQuizzes).hasSize(80);
            assertThat(networkQuizzes).hasSize(80);
            assertThat(computerArchitectureQuizzes).hasSize(80);
            assertThat(dataStructuresQuizzes).hasSize(80);
            IntStream.rangeClosed(1, 12).forEach(stepOrder -> assertFormalStep(osQuizzes, stepOrder));
            IntStream.rangeClosed(1, 16).forEach(stepOrder -> assertFormalStep(designPatternQuizzes, stepOrder));
            IntStream.rangeClosed(1, 16).forEach(stepOrder -> assertFormalStep(networkQuizzes, stepOrder));
            IntStream.rangeClosed(1, 16).forEach(stepOrder -> assertFormalStep(computerArchitectureQuizzes, stepOrder));
            IntStream.rangeClosed(1, 16).forEach(stepOrder -> assertFormalStep(dataStructuresQuizzes, stepOrder));
        }

        @Test
        @DisplayName("모든 문제는 답안 유형에 맞는 정답 필드와 자식 구조를 갖는다")
        void keeps_type_specific_answer_structure() {
            quizRepository.findAll().forEach(QuizSeedDataIntegrityTest.this::assertTypeSpecificFields);
        }
    }

    @Nested
    @DisplayName("코드 지문 감사")
    class CodeSnippetAudit {

        @Test
        @DisplayName("검수된 9개 좌표에만 코드 지문이 있고 모두 코드 구조 검증을 통과한다")
        void keeps_only_reviewed_code_snippets() {
            List<Quiz> quizzesWithCode = quizRepository.findAll().stream()
                    .filter(quiz -> quiz.getCodeSnippet() != null)
                    .toList();
            Long osCourseId = courseIdByTitle("운영체제");
            Long designPatternCourseId = courseIdByTitle("디자인 패턴");
            Map<Long, Long> courseIdByQuizId = courseIdByQuizId(quizRepository.findAll());
            Set<Coordinate> reviewedCodeSnippets = Set.of(
                    new Coordinate(osCourseId, 1, 4),
                    new Coordinate(osCourseId, 3, 4),
                    new Coordinate(osCourseId, 6, 4),
                    new Coordinate(osCourseId, 7, 4),
                    new Coordinate(osCourseId, 8, 4),
                    new Coordinate(osCourseId, 9, 4),
                    new Coordinate(osCourseId, 11, 4),
                    new Coordinate(osCourseId, 12, 4),
                    new Coordinate(designPatternCourseId, 1, 4));

            assertThat(quizzesWithCode)
                    .extracting(quiz -> new Coordinate(
                            courseIdByQuizId.get(quiz.getId()), quiz.getStepOrder(), quiz.getSlotOrder()))
                    .containsExactlyInAnyOrderElementsOf(reviewedCodeSnippets);
            quizzesWithCode.forEach(
                    quiz -> assertThatCode(() -> CodeSnippetValidator.validate(location(quiz), quiz.getCodeSnippet()))
                            .doesNotThrowAnyException());
        }

        @Test
        @DisplayName("오분류 네 문제는 상황을 본문에 보존하고 코드 지문을 비운다")
        void moves_non_code_context_into_question_text() {
            Long osCourseId = courseIdByTitle("운영체제");
            assertCorrectedQuiz(
                    osCourseId,
                    2,
                    "단일 CPU 환경에서 CPU를 사용 중인 프로세스 P에 타이머 인터럽트가 발생했다. "
                            + "P는 종료되거나 입출력을 요청하지 않았으며, 운영체제는 P의 실행 정보를 저장한 뒤 "
                            + "다른 프로세스에 CPU를 넘겼다. 이때 P의 상태 전이로 가장 알맞은 것을 고르시오.",
                    "Running → Ready");
            assertCorrectedQuiz(
                    osCourseId,
                    4,
                    "세 프로세스 P1(우선순위 3), P2(우선순위 1), P3(우선순위 2)가 모두 같은 시각에 준비 상태가 된다. "
                            + "숫자가 작을수록 우선순위가 높으며, 비선점형 우선순위 스케줄링을 사용한다. "
                            + "이 상황에 대한 설명으로 옳은 것을 고르시오.",
                    "P2가 먼저 실행된다.");
            assertCorrectedQuiz(
                    osCourseId,
                    5,
                    "프로세스 A(우선순위 3, 버스트 시간 5), B(우선순위 1, 버스트 시간 8), "
                            + "C(우선순위 2, 버스트 시간 2), D(우선순위 4, 버스트 시간 1)가 모두 시각 0에 준비 큐에 있다. "
                            + "숫자가 작을수록 우선순위가 높은 선점형 우선순위 스케줄링을 사용할 때, "
                            + "가장 먼저 CPU를 할당받는 프로세스로 알맞은 것을 고르시오.",
                    "Process B");
            assertCorrectedQuiz(
                    osCourseId,
                    10,
                    "페이지 프레임이 3개이고 페이지 참조열이 [1, 2, 3, 2, 4] 순서로 주어졌을 때, "
                            + "LRU 알고리즘의 설명으로 가장 알맞은 것을 고르시오. 각 숫자는 페이지 번호를 의미한다.",
                    "페이지 1이 교체된다. 가장 오래 전에 사용되었기 때문이다.");
        }
    }

    private void assertFormalStep(List<Quiz> formal, int stepOrder) {
        List<Quiz> step = formal.stream()
                .filter(quiz -> quiz.getStepOrder() == stepOrder)
                .sorted(Comparator.comparingInt(Quiz::getSlotOrder))
                .toList();

        assertThat(step).hasSize(5);
        assertThat(step).extracting(Quiz::getSlotOrder).containsExactly(1, 2, 3, 4, 5);
        assertSlot(step.get(0), QuizType.OX, QuizDifficulty.EASY);
        assertSlot(step.get(1), QuizType.OX, QuizDifficulty.EASY);
        assertSlot(step.get(2), QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM);
        assertSlot(step.get(3), QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM);
        assertSlot(step.get(4), QuizType.KEYWORD_BLANK, QuizDifficulty.HARD);
    }

    private void assertSlot(Quiz quiz, QuizType type, QuizDifficulty difficulty) {
        assertThat(quiz.getType()).as(location(quiz)).isEqualTo(type);
        assertThat(quiz.getDifficulty()).as(location(quiz)).isEqualTo(difficulty);
    }

    private void assertTypeSpecificFields(Quiz quiz) {
        assertThat(quiz.getQuestionText()).as(location(quiz)).isNotBlank();
        assertThat(quiz.getExplanationSummary()).as(location(quiz)).isNotBlank();
        assertThat(quiz.getWrongAnswerExplanation()).as(location(quiz)).isNotBlank();
        if (quiz.getCodeSnippet() != null) {
            assertThat(quiz.getCodeSnippet()).as(location(quiz)).isNotBlank();
        }

        if (quiz.getType() == QuizType.OX) {
            assertThat(quiz.getCorrectAnswer()).as(location(quiz)).isIn("O", "X");
            assertThat(quiz.getChoices()).as(location(quiz)).isEmpty();
            assertThat(quiz.getAnswerKeywords()).as(location(quiz)).isEmpty();
        } else if (quiz.getType() == QuizType.MULTIPLE_CHOICE) {
            assertThat(quiz.getCorrectAnswer()).as(location(quiz)).isNull();
            assertThat(quiz.getChoices()).as(location(quiz)).hasSize(4);
            assertThat(quiz.getChoices())
                    .as(location(quiz))
                    .filteredOn(QuizChoice::isCorrect)
                    .hasSize(1);
            assertThat(quiz.getAnswerKeywords()).as(location(quiz)).isEmpty();
        } else {
            assertThat(quiz.getCorrectAnswer()).as(location(quiz)).isNull();
            assertThat(quiz.getChoices()).as(location(quiz)).isEmpty();
            long blankCount =
                    BLANK_PATTERN.matcher(quiz.getQuestionText()).results().count();
            List<Integer> answerSlots = quiz.getAnswerKeywords().stream()
                    .mapToInt(answer -> answer.getSlotOrder())
                    .distinct()
                    .sorted()
                    .boxed()
                    .toList();
            assertThat(blankCount).as(location(quiz)).isPositive();
            assertThat(answerSlots)
                    .as(location(quiz))
                    .containsExactlyElementsOf(IntStream.rangeClosed(1, Math.toIntExact(blankCount))
                            .boxed()
                            .toList());
        }
    }

    private void assertCorrectedQuiz(Long courseId, int stepOrder, String questionText, String correctChoice) {
        List<Quiz> quizzes = quizRepository.findAll();
        Map<Long, Long> courseIdByQuizId = courseIdByQuizId(quizzes);
        Quiz quiz = quizzes.stream()
                .filter(q -> q.getStepOrder() == stepOrder
                        && q.getSlotOrder() == 4
                        && courseIdByQuizId.get(q.getId()).equals(courseId))
                .findFirst()
                .orElseThrow();

        assertThat(quiz.getQuestionText()).isEqualTo(questionText);
        assertThat(quiz.getCodeSnippet()).isNull();
        assertThat(quiz.getChoices())
                .filteredOn(QuizChoice::isCorrect)
                .extracting(QuizChoice::getContent)
                .containsExactly(correctChoice);
    }

    private String location(Quiz quiz) {
        return "step %d / slot %d".formatted(quiz.getStepOrder(), quiz.getSlotOrder());
    }

    private record Coordinate(Long courseId, int stepOrder, int slotOrder) {}
}
