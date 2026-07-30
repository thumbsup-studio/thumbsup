package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.tuple;

import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/** Repository 통합 테스트 — 코스 목록 조회(#247)가 쓰는 배치 조회를 실제 MySQL로 검증한다 (피라미드 3층). */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@ActiveProfiles("test")
class QuizStepRepositoryTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private static final Long COURSE_A = 1L;
    private static final Long COURSE_B = 2L;
    private static final Long COURSE_C = 3L;

    private final QuizStepRepository quizStepRepository;

    QuizStepRepositoryTest(@Autowired QuizStepRepository quizStepRepository) {
        this.quizStepRepository = quizStepRepository;
    }

    @Nested
    @DisplayName("findByCourseIdInOrderByCourseIdAscStepOrderAsc")
    class FindByCourseIdInOrderByCourseIdAscStepOrderAsc {

        @Test
        @DisplayName("여러 코스의 스텝을 코스별로 stepOrder 오름차순으로 묶어 반환한다")
        void returns_steps_grouped_and_sorted_by_course() {
            quizStepRepository.save(QuizStep.create(2, COURSE_A, "A2", 3));
            quizStepRepository.save(QuizStep.create(1, COURSE_A, "A1", 3));
            quizStepRepository.save(QuizStep.create(13, COURSE_B, "B1", 4));

            List<QuizStep> result =
                    quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(COURSE_A, COURSE_B));

            assertThat(result)
                    .extracting(QuizStep::getCourseId, QuizStep::getStepOrder)
                    .containsExactly(tuple(COURSE_A, 1), tuple(COURSE_A, 2), tuple(COURSE_B, 13));
        }

        @Test
        @DisplayName("조회 대상에 없는 코스의 스텝은 섞이지 않는다")
        void excludes_steps_of_courses_not_requested() {
            quizStepRepository.save(QuizStep.create(1, COURSE_A, "A1", 3));
            quizStepRepository.save(QuizStep.create(2, COURSE_C, "C1", 3));

            List<QuizStep> result =
                    quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(COURSE_A));

            assertThat(result).extracting(QuizStep::getCourseId).containsExactly(COURSE_A);
        }

        @Test
        @DisplayName("빈 코스 목록으로 조회하면 빈 목록을 반환한다")
        void returns_empty_when_no_course_ids_given() {
            quizStepRepository.save(QuizStep.create(1, COURSE_A, "A1", 3));

            List<QuizStep> result = quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of());

            assertThat(result).isEmpty();
        }
    }
}
