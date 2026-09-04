package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.stream.Collectors;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import studio.thumbsup.server.common.support.RepositoryTestSupport;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizAnswerKeyword;
import studio.thumbsup.server.quiz.QuizFollowUpQuestion;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepBriefing;
import studio.thumbsup.server.quiz.QuizStepBriefingRepository;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;

/** #315 네트워크 시드가 승인된 저작 payload의 구조와 콘텐츠 검증 규칙을 그대로 보존하는지 감사한다. */
class NetworkCourseSeedIntegrityTest extends RepositoryTestSupport {

    private static final String COURSE_TITLE = "컴퓨터 네트워크";
    private static final List<String> TOPICS = List.of(
            "계층 모델과 캡슐화",
            "이더넷과 스위칭",
            "IPv4 주소와 CIDR",
            "호스트 구성과 DHCP",
            "서브넷·ARP·IP 전달",
            "라우팅과 ICMP 진단",
            "NAT와 NAPT",
            "IPv6와 Neighbor Discovery",
            "전송 계층과 TCP·UDP",
            "TCP 연결 수립과 종료",
            "TCP 신뢰성과 흐름 제어",
            "TCP 혼잡 제어와 성능",
            "DNS 이름 해석",
            "HTTP 의미와 캐시",
            "TLS와 HTTP 전송 버전",
            "URL 입력부터 응답까지");

    private final GeneratedQuizValidator validator = new GeneratedQuizValidator(new ObjectMapper());
    private final CourseRepository courseRepository;
    private final QuizStepRepository quizStepRepository;
    private final QuizRepository quizRepository;
    private final QuizStepBriefingRepository briefingRepository;
    private final JdbcTemplate jdbcTemplate;

    NetworkCourseSeedIntegrityTest(
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
    @DisplayName("네트워크 코스의 16개 스텝과 모든 자식 콘텐츠를 누락 없이 저장한다")
    void persists_the_complete_network_course_graph() {
        Course course = networkCourse();
        assertThat(course.getCategory()).isEqualTo("CS");

        List<QuizStep> steps = networkSteps(course.getId());
        assertThat(steps).extracting(QuizStep::getStepOrder).containsExactlyElementsOf(range(1, 16));
        assertThat(steps).extracting(QuizStep::getTopic).containsExactlyElementsOf(TOPICS);
        assertThat(steps).extracting(QuizStep::getEstimatedMinutes).containsOnly(3);

        assertThat(queryCounts(course.getId()))
                .isEqualTo(new NetworkCounts(16, 60, 80, 128, 150, 80, 109, 99, 215, 153));
    }

    @Test
    @DisplayName("DB에서 복원한 80문제와 브리핑이 저작 파이프라인 검증을 다시 통과한다")
    void keeps_every_authored_content_invariant_after_sql_round_trip() {
        for (QuizStep step : networkSteps(networkCourse().getId())) {
            List<Quiz> quizzes = quizRepository.findByQuizStepIdOrderBySlotOrderAsc(step.getId());
            QuizStepBriefing briefing =
                    briefingRepository.findWithBlocksByQuizStepId(step.getId()).orElseThrow();
            GeneratedQuizSet generated = new GeneratedQuizSet(
                    GeneratedQuizSet.STEP_BRIEFING_SCHEMA_VERSION,
                    toGeneratedBriefing(briefing),
                    quizzes.stream().map(this::toGeneratedQuiz).toList());

            assertThatCode(() -> validator.validateStepContent(generated, QuizPreset.BASIC_5))
                    .as("step %d: %s".formatted(step.getStepOrder(), step.getTopic()))
                    .doesNotThrowAnyException();
        }
    }

    private Course networkCourse() {
        return courseRepository.findAll().stream()
                .filter(course -> course.getTitle().equals(COURSE_TITLE))
                .findFirst()
                .orElseThrow();
    }

    private List<QuizStep> networkSteps(Long courseId) {
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

    private GeneratedQuizSet.GeneratedQuiz toGeneratedQuiz(Quiz quiz) {
        Map<Integer, List<String>> answerKeywords = quiz.getAnswerKeywords().stream()
                .collect(Collectors.groupingBy(
                        QuizAnswerKeyword::getSlotOrder,
                        TreeMap::new,
                        Collectors.mapping(QuizAnswerKeyword::getKeyword, Collectors.toList())));
        return new GeneratedQuizSet.GeneratedQuiz(
                quiz.getType(),
                quiz.getDifficulty(),
                quiz.getQuestionText(),
                quiz.getHint(),
                quiz.getCodeSnippet(),
                quiz.getExplanationSummary(),
                quiz.getExplanationExample(),
                quiz.getWrongAnswerExplanation(),
                quiz.getCorrectAnswer(),
                quiz.getChoices().stream()
                        .map(choice -> new GeneratedQuizSet.GeneratedChoice(choice.getContent(), choice.isCorrect()))
                        .toList(),
                answerKeywords.values().stream().toList(),
                quiz.getFollowUpQuestions().stream()
                        .map(this::toGeneratedFollowUp)
                        .toList(),
                quiz.getDerivedConcepts().stream()
                        .map(concept -> concept.getName())
                        .toList(),
                quiz.getKeywords().stream()
                        .map(keyword ->
                                new GeneratedQuizSet.GeneratedKeyword(keyword.getKeyword(), keyword.getDescription()))
                        .toList());
    }

    private GeneratedQuizSet.GeneratedFollowUpQuestion toGeneratedFollowUp(QuizFollowUpQuestion followUp) {
        return new GeneratedQuizSet.GeneratedFollowUpQuestion(
                followUp.getContent(),
                followUp.isPrimary(),
                followUp.getDifficulty(),
                followUp.getOneLineAnswer(),
                followUp.getBlocks().stream()
                        .map(block -> new GeneratedQuizSet.GeneratedFollowUpBlock(block.getLabel(), block.getContent()))
                        .toList(),
                followUp.getKeywords().stream()
                        .map(keyword ->
                                new GeneratedQuizSet.GeneratedKeyword(keyword.getKeyword(), keyword.getDescription()))
                        .toList());
    }

    private NetworkCounts queryCounts(Long courseId) {
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
                (resultSet, rowNumber) -> new NetworkCounts(
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

    private record NetworkCounts(
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
