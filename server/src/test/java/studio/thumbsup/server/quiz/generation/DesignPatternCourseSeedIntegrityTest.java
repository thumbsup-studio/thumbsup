package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import studio.thumbsup.server.common.support.RepositoryTestSupport;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepBriefing;
import studio.thumbsup.server.quiz.QuizStepBriefingRepository;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.authoring.QuizToGeneratedQuizMapper;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;

/** #318 디자인 패턴 확장 시드가 승인된 저작 payload의 구조와 콘텐츠 검증 규칙을 그대로 보존하는지 감사한다. */
class DesignPatternCourseSeedIntegrityTest extends RepositoryTestSupport {

    private static final String COURSE_TITLE = "디자인 패턴";
    private static final List<String> TOPICS = List.of(
            "생성 패턴 개요와 싱글턴(스레드 안전성 포함)",
            "팩토리 메서드와 추상 팩토리",
            "빌더와 안전한 객체 조립",
            "프로토타입과 복사 의미",
            "어댑터와 인터페이스 변환",
            "브리지와 독립적인 변화 축",
            "컴포지트와 부분-전체 계층",
            "데코레이터 패턴 — 객체를 감싸 기능을 조합하기",
            "퍼사드와 프록시 패턴 — 단순화와 대리의 의도 구분",
            "이터레이터 패턴 — 컬렉션 내부를 숨기고 순회하기",
            "전략 패턴 — 알고리즘을 교체 가능한 객체로 분리하기",
            "옵서버 패턴 — 상태 변화를 여러 구독자에게 알리기",
            "커맨드와 요청 객체화",
            "상태 패턴과 상태 전이",
            "템플릿 메서드와 확장 훅",
            "책임 연쇄와 처리 파이프라인");

    private final GeneratedQuizValidator validator = new GeneratedQuizValidator(new ObjectMapper());
    private final CourseRepository courseRepository;
    private final QuizStepRepository quizStepRepository;
    private final QuizRepository quizRepository;
    private final QuizStepBriefingRepository briefingRepository;
    private final JdbcTemplate jdbcTemplate;

    DesignPatternCourseSeedIntegrityTest(
            @Autowired CourseRepository courseRepository,
            @Autowired QuizStepRepository quizStepRepository,
            @Autowired QuizRepository quizRepository,
            @Autowired QuizStepBriefingRepository briefingRepository,
            @Autowired JdbcTemplate jdbcTemplate) {
        this.courseRepository = courseRepository;
        this.quizStepRepository = quizStepRepository;
        this.quizRepository = quizRepository;
        this.briefingRepository = briefingRepository;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Test
    @DisplayName("디자인 패턴 코스의 16개 스텝과 모든 자식 콘텐츠를 누락 없이 저장한다")
    void persists_the_complete_design_pattern_course_graph() {
        Course course = designPatternCourse();
        assertThat(course.getCategory()).isEqualTo("CS");

        List<QuizStep> steps = designPatternSteps(course.getId());
        assertThat(steps).extracting(QuizStep::getStepOrder).containsExactlyElementsOf(range(1, 16));
        assertThat(steps).extracting(QuizStep::getTopic).containsExactlyElementsOf(TOPICS);
        assertThat(steps).extracting(QuizStep::getEstimatedMinutes).containsOnly(3);

        assertThat(queryCounts(course.getId()))
                .isEqualTo(new DesignPatternCounts(16, 59, 80, 128, 42, 85, 167, 112, 240, 107));
    }

    @Test
    @DisplayName("DB에서 복원한 80문제와 브리핑이 저작 파이프라인 검증을 다시 통과한다")
    void keeps_every_authored_content_invariant_after_sql_round_trip() {
        for (QuizStep step : designPatternSteps(designPatternCourse().getId())) {
            List<Quiz> quizzes = quizRepository.findByQuizStepIdOrderBySlotOrderAsc(step.getId());
            QuizStepBriefing briefing =
                    briefingRepository.findWithBlocksByQuizStepId(step.getId()).orElseThrow();
            GeneratedQuizSet generated = new GeneratedQuizSet(
                    GeneratedQuizSet.STEP_BRIEFING_SCHEMA_VERSION,
                    toGeneratedBriefing(briefing),
                    quizzes.stream().map(QuizToGeneratedQuizMapper::toGenerated).toList());

            assertThatCode(() -> validator.validateStepContent(generated, QuizPreset.BASIC_5))
                    .as("step %d: %s".formatted(step.getStepOrder(), step.getTopic()))
                    .doesNotThrowAnyException();
        }
    }

    private Course designPatternCourse() {
        return courseRepository.findAll().stream()
                .filter(course -> course.getTitle().equals(COURSE_TITLE))
                .findFirst()
                .orElseThrow();
    }

    private List<QuizStep> designPatternSteps(Long courseId) {
        return quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(courseId));
    }

    private GeneratedQuizSet.GeneratedBriefing toGeneratedBriefing(QuizStepBriefing briefing) {
        return new GeneratedQuizSet.GeneratedBriefing(
                briefing.getSummary(),
                briefing.getBlocks().stream()
                        .map(block -> new GeneratedQuizSet.GeneratedBriefingBlock(
                                block.getType(), block.getHeading(), block.getContent()))
                        .toList());
    }

    private DesignPatternCounts queryCounts(Long courseId) {
        return jdbcTemplate.queryForObject(
                """
                SELECT
                    (SELECT COUNT(*) FROM quiz_step qs WHERE qs.course_id = ?),
                    (SELECT COUNT(*) FROM quiz_step_briefing_block qsbb
                        JOIN quiz_step_briefing qsb ON qsb.id = qsbb.briefing_id
                        JOIN quiz_step qs ON qs.id = qsb.quiz_step_id WHERE qs.course_id = ?),
                    (SELECT COUNT(*) FROM quiz q JOIN quiz_step qs ON qs.id = q.quiz_step_id WHERE qs.course_id = ?),
                    (SELECT COUNT(*) FROM quiz_choice qc JOIN quiz q ON q.id = qc.quiz_id
                        JOIN quiz_step qs ON qs.id = q.quiz_step_id WHERE qs.course_id = ?),
                    (SELECT COUNT(*) FROM quiz_answer_keyword qak JOIN quiz q ON q.id = qak.quiz_id
                        JOIN quiz_step qs ON qs.id = q.quiz_step_id WHERE qs.course_id = ?),
                    (SELECT COUNT(*) FROM quiz_follow_up_question qfq JOIN quiz q ON q.id = qfq.quiz_id
                        JOIN quiz_step qs ON qs.id = q.quiz_step_id WHERE qs.course_id = ?),
                    (SELECT COUNT(*) FROM quiz_follow_up_block qfb
                        JOIN quiz_follow_up_question qfq ON qfq.id = qfb.follow_up_question_id
                        JOIN quiz q ON q.id = qfq.quiz_id
                        JOIN quiz_step qs ON qs.id = q.quiz_step_id WHERE qs.course_id = ?),
                    (SELECT COUNT(*) FROM quiz_follow_up_keyword qfk
                        JOIN quiz_follow_up_question qfq ON qfq.id = qfk.follow_up_question_id
                        JOIN quiz q ON q.id = qfq.quiz_id
                        JOIN quiz_step qs ON qs.id = q.quiz_step_id WHERE qs.course_id = ?),
                    (SELECT COUNT(*) FROM quiz_derived_tag qdc JOIN quiz q ON q.id = qdc.quiz_id
                        JOIN quiz_step qs ON qs.id = q.quiz_step_id WHERE qs.course_id = ?),
                    (SELECT COUNT(*) FROM quiz_keyword qk JOIN quiz q ON q.id = qk.quiz_id
                        JOIN quiz_step qs ON qs.id = q.quiz_step_id WHERE qs.course_id = ?)
                """,
                (resultSet, rowNumber) -> new DesignPatternCounts(
                        resultSet.getInt(1),
                        resultSet.getInt(2),
                        resultSet.getInt(3),
                        resultSet.getInt(4),
                        resultSet.getInt(5),
                        resultSet.getInt(6),
                        resultSet.getInt(7),
                        resultSet.getInt(8),
                        resultSet.getInt(9),
                        resultSet.getInt(10)),
                courseId,
                courseId,
                courseId,
                courseId,
                courseId,
                courseId,
                courseId,
                courseId,
                courseId,
                courseId);
    }

    private List<Integer> range(int start, int end) {
        return java.util.stream.IntStream.rangeClosed(start, end).boxed().toList();
    }

    private record DesignPatternCounts(
            int steps,
            int briefingBlocks,
            int quizzes,
            int choices,
            int answerKeywords,
            int followUps,
            int followUpBlocks,
            int followUpKeywords,
            int derivedTags,
            int quizKeywords) {}
}
