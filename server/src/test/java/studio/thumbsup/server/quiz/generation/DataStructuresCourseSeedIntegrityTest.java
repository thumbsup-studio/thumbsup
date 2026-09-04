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

/** #320 자료구조 시드가 승인된 저작 payload의 구조와 콘텐츠 검증 규칙을 그대로 보존하는지 감사한다. */
class DataStructuresCourseSeedIntegrityTest extends RepositoryTestSupport {

    private static final String COURSE_TITLE = "자료구조";
    private static final List<String> TOPICS = List.of(
            "키로 찾기 — 해시 맵과 해시 셋을 고르는 기준",
            "해시 키의 동일성 — 동등성과 해시값 계약",
            "충돌은 오류가 아니다 — 체이닝과 개방 주소법",
            "평균 O(1)의 조건 — 적재율, 리사이즈, 최악의 경우",
            "트리로 표현할 수 있는 관계",
            "이진 트리의 모양과 이진 탐색 트리의 순서",
            "BST의 성능은 높이에 달려 있다",
            "균형 잡힌 순서 구조와 해시 중 고르기",
            "우선순위 큐와 힙은 같은 말이 아니다",
            "힙 불변식 — 루트만 확실하고 전체는 정렬되지 않는다",
            "배열로 저장하는 힙과 기본 연산",
            "힙을 선택하거나 피해야 하는 상황",
            "데이터가 그래프가 되는 순간",
            "방향·가중치·사이클을 요구사항으로 결정하기",
            "인접 리스트·인접 행렬·간선 목록 비교",
            "요구사항에서 복합 자료구조까지 — 최종 선택");

    private final GeneratedQuizValidator validator = new GeneratedQuizValidator(new ObjectMapper());
    private final CourseRepository courseRepository;
    private final QuizStepRepository quizStepRepository;
    private final QuizRepository quizRepository;
    private final QuizStepBriefingRepository briefingRepository;
    private final JdbcTemplate jdbcTemplate;

    DataStructuresCourseSeedIntegrityTest(
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
    @DisplayName("자료구조 코스의 16개 스텝과 모든 자식 콘텐츠를 누락 없이 저장한다")
    void persists_the_complete_data_structures_course_graph() {
        Course course = dataStructuresCourse();
        assertThat(course.getCategory()).isEqualTo("CS");

        List<QuizStep> steps = dataStructuresSteps(course.getId());
        assertThat(steps).extracting(QuizStep::getStepOrder).containsExactlyElementsOf(range(1, 16));
        assertThat(steps).extracting(QuizStep::getTopic).containsExactlyElementsOf(TOPICS);
        assertThat(steps).extracting(QuizStep::getEstimatedMinutes).containsOnly(3);

        assertThat(queryCounts(course.getId()))
                .isEqualTo(new DataStructuresCounts(16, 51, 80, 128, 39, 80, 80, 80, 240, 80));
    }

    @Test
    @DisplayName("DB에서 복원한 80문제와 브리핑이 저작 파이프라인 검증을 다시 통과한다")
    void keeps_every_authored_content_invariant_after_sql_round_trip() {
        for (QuizStep step : dataStructuresSteps(dataStructuresCourse().getId())) {
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

    private Course dataStructuresCourse() {
        return courseRepository.findAll().stream()
                .filter(course -> course.getTitle().equals(COURSE_TITLE))
                .findFirst()
                .orElseThrow();
    }

    private List<QuizStep> dataStructuresSteps(Long courseId) {
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

    private DataStructuresCounts queryCounts(Long courseId) {
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
                    (SELECT COUNT(*) FROM quiz_derived_concept qdc JOIN quiz q ON q.id = qdc.quiz_id
                        JOIN quiz_step qs ON qs.id = q.quiz_step_id WHERE qs.course_id = ?),
                    (SELECT COUNT(*) FROM quiz_keyword qk JOIN quiz q ON q.id = qk.quiz_id
                        JOIN quiz_step qs ON qs.id = q.quiz_step_id WHERE qs.course_id = ?)
                """,
                (resultSet, rowNumber) -> new DataStructuresCounts(
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

    private record DataStructuresCounts(
            int steps,
            int briefingBlocks,
            int quizzes,
            int choices,
            int answerKeywords,
            int followUps,
            int followUpBlocks,
            int followUpKeywords,
            int derivedConcepts,
            int quizKeywords) {}
}
