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

/** #319 컴퓨터 구조 시드가 승인된 저작 payload의 구조와 콘텐츠 검증 규칙을 그대로 보존하는지 감사한다. */
class ComputerArchitectureCourseSeedIntegrityTest extends RepositoryTestSupport {

    private static final String COURSE_TITLE = "컴퓨터 구조";
    private static final List<String> TOPICS = List.of(
            "명령이 하드웨어를 지나는 전체 흐름",
            "명령어 집합과 기계어",
            "레지스터와 CPU의 실행 상태",
            "인출·해독·실행",
            "ALU, 분기와 주소 계산",
            "CPU 성능을 읽는 기준",
            "주기억장치와 주소",
            "메모리 계층과 지역성",
            "CPU 캐시의 hit·miss와 cache line",
            "캐시 주소 분해와 직접 매핑",
            "연관도와 충돌 미스",
            "교체·쓰기 정책과 다단계 캐시",
            "파이프라인과 겹쳐 실행하기",
            "데이터 해저드와 포워딩",
            "제어 해저드와 구조적 해저드",
            "한 명령 흐름으로 병목 진단하기");

    private final GeneratedQuizValidator validator = new GeneratedQuizValidator(new ObjectMapper());
    private final CourseRepository courseRepository;
    private final QuizStepRepository quizStepRepository;
    private final QuizRepository quizRepository;
    private final QuizStepBriefingRepository briefingRepository;
    private final JdbcTemplate jdbcTemplate;

    ComputerArchitectureCourseSeedIntegrityTest(
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
    @DisplayName("컴퓨터 구조 코스의 16개 스텝과 모든 자식 콘텐츠를 누락 없이 저장한다")
    void persists_the_complete_computer_architecture_course_graph() {
        Course course = computerArchitectureCourse();
        assertThat(course.getCategory()).isEqualTo("CS");

        List<QuizStep> steps = computerArchitectureSteps(course.getId());
        assertThat(steps).extracting(QuizStep::getStepOrder).containsExactlyElementsOf(range(1, 16));
        assertThat(steps).extracting(QuizStep::getTopic).containsExactlyElementsOf(TOPICS);
        assertThat(steps).extracting(QuizStep::getEstimatedMinutes).containsOnly(3);

        assertThat(queryCounts(course.getId()))
                .isEqualTo(new ComputerArchitectureCounts(16, 49, 80, 128, 44, 80, 105, 80, 240, 80));
    }

    @Test
    @DisplayName("DB에서 복원한 80문제와 브리핑이 저작 파이프라인 검증을 다시 통과한다")
    void keeps_every_authored_content_invariant_after_sql_round_trip() {
        for (QuizStep step :
                computerArchitectureSteps(computerArchitectureCourse().getId())) {
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

    private Course computerArchitectureCourse() {
        return courseRepository.findAll().stream()
                .filter(course -> course.getTitle().equals(COURSE_TITLE))
                .findFirst()
                .orElseThrow();
    }

    private List<QuizStep> computerArchitectureSteps(Long courseId) {
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

    private ComputerArchitectureCounts queryCounts(Long courseId) {
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
                (resultSet, rowNumber) -> new ComputerArchitectureCounts(
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

    private record ComputerArchitectureCounts(
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
