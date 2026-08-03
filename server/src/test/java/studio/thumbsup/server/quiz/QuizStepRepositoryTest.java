package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.tuple;

import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.DatabaseCleanUp;
import studio.thumbsup.server.common.config.ClockConfig;
import studio.thumbsup.server.common.config.JpaAuditingConfig;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;

/** Repository 통합 테스트 — 코스 목록 조회(#247)가 쓰는 배치 조회를 실제 MySQL로 검증한다 (피라미드 3층). */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@Import({ClockConfig.class, JpaAuditingConfig.class, DatabaseCleanUp.class})
@ActiveProfiles("test")
class QuizStepRepositoryTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final QuizStepRepository quizStepRepository;
    private final CourseRepository courseRepository;
    private final DatabaseCleanUp databaseCleanUp;

    private Long courseA;
    private Long courseB;
    private Long courseC;

    QuizStepRepositoryTest(
            @Autowired QuizStepRepository quizStepRepository,
            @Autowired CourseRepository courseRepository,
            @Autowired DatabaseCleanUp databaseCleanUp) {
        this.quizStepRepository = quizStepRepository;
        this.courseRepository = courseRepository;
        this.databaseCleanUp = databaseCleanUp;
    }

    // Flyway 시드가 step_order 0~12(OS 코스)·13번~(디자인패턴)을 이미 커밋해 둔다 — 테스트가 쓰는
    // step_order 값이 시드와 충돌하지 않도록 각 테스트 실행 전 모든 테이블을 TRUNCATE하고,
    // quiz_step.course_id가 참조할 코스를 새로 만든다.
    @BeforeEach
    void setUp() {
        databaseCleanUp.execute();
        courseA = courseRepository.save(Course.create("A", "CS")).getId();
        courseB = courseRepository.save(Course.create("B", "CS")).getId();
        courseC = courseRepository.save(Course.create("C", "CS")).getId();
    }

    @Nested
    @DisplayName("findByCourseIdInOrderByCourseIdAscStepOrderAsc")
    class FindByCourseIdInOrderByCourseIdAscStepOrderAsc {

        @Test
        @DisplayName("여러 코스의 스텝을 코스별로 stepOrder 오름차순으로 묶어 반환한다")
        void returns_steps_grouped_and_sorted_by_course() {
            quizStepRepository.save(QuizStep.create(2, courseA, "A2", 3));
            quizStepRepository.save(QuizStep.create(1, courseA, "A1", 3));
            quizStepRepository.save(QuizStep.create(13, courseB, "B1", 4));

            List<QuizStep> result =
                    quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(courseA, courseB));

            assertThat(result)
                    .extracting(QuizStep::getCourseId, QuizStep::getStepOrder)
                    .containsExactly(tuple(courseA, 1), tuple(courseA, 2), tuple(courseB, 13));
        }

        @Test
        @DisplayName("조회 대상에 없는 코스의 스텝은 섞이지 않는다")
        void excludes_steps_of_courses_not_requested() {
            quizStepRepository.save(QuizStep.create(1, courseA, "A1", 3));
            quizStepRepository.save(QuizStep.create(2, courseC, "C1", 3));

            List<QuizStep> result = quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(courseA));

            assertThat(result).extracting(QuizStep::getCourseId).containsExactly(courseA);
        }

        @Test
        @DisplayName("빈 코스 목록으로 조회하면 빈 목록을 반환한다")
        void returns_empty_when_no_course_ids_given() {
            quizStepRepository.save(QuizStep.create(1, courseA, "A1", 3));

            List<QuizStep> result = quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of());

            assertThat(result).isEmpty();
        }

        @Test
        @DisplayName("stepOrder=0 placeholder(quiz FK sentinel, #257)는 결과에서 제외한다")
        void excludes_step_zero_placeholder() {
            quizStepRepository.save(QuizStep.create(0, courseA, "(미배정)", 0));
            quizStepRepository.save(QuizStep.create(1, courseA, "A1", 3));

            List<QuizStep> result = quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(courseA));

            assertThat(result).extracting(QuizStep::getStepOrder).containsExactly(1);
        }

        @Test
        @DisplayName("전체 quiz_step 중 가장 큰 step_order를 반환한다")
        void finds_global_max_step_order() {
            quizStepRepository.save(QuizStep.create(4, courseA, "A4", 3));
            quizStepRepository.save(QuizStep.create(9, courseB, "B9", 3));

            assertThat(quizStepRepository.findMaxStepOrder()).contains(9);
        }
    }

    @Nested
    @DisplayName("findMinStepOrderByCourseId")
    class FindMinStepOrderByCourseId {

        @Test
        @DisplayName("코스의 실제 시작 스텝(stepOrder 최솟값)을 반환한다")
        void returns_min_step_order() {
            quizStepRepository.save(QuizStep.create(3, courseA, "A3", 3));
            quizStepRepository.save(QuizStep.create(1, courseA, "A1", 3));

            assertThat(quizStepRepository.findMinStepOrderByCourseId(courseA)).contains(1);
        }

        @Test
        @DisplayName("stepOrder=0 placeholder(quiz FK sentinel, #257)는 시작 스텝 계산에서 제외한다")
        void excludes_step_zero_placeholder() {
            quizStepRepository.save(QuizStep.create(0, courseA, "(미배정)", 0));
            quizStepRepository.save(QuizStep.create(1, courseA, "A1", 3));

            assertThat(quizStepRepository.findMinStepOrderByCourseId(courseA)).contains(1);
        }

        @Test
        @DisplayName("placeholder를 제외하면 실제 스텝이 없는 코스는 빈 값을 반환한다")
        void returns_empty_when_only_placeholder_exists() {
            quizStepRepository.save(QuizStep.create(0, courseA, "(미배정)", 0));

            assertThat(quizStepRepository.findMinStepOrderByCourseId(courseA)).isEmpty();
        }
    }

    @Nested
    @DisplayName("countByCourseId")
    class CountByCourseId {

        @Test
        @DisplayName("stepOrder=0 placeholder(quiz FK sentinel, #257)를 제외한 실제 스텝 수를 반환한다")
        void excludes_step_zero_placeholder() {
            quizStepRepository.save(QuizStep.create(0, courseA, "(미배정)", 0));
            quizStepRepository.save(QuizStep.create(1, courseA, "A1", 3));
            quizStepRepository.save(QuizStep.create(2, courseA, "A2", 3));

            assertThat(quizStepRepository.countByCourseId(courseA)).isEqualTo(2);
        }
    }
}
