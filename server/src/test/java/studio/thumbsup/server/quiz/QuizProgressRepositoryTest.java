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

/** Repository 통합 테스트 — 코스 목록 조회(#247)가 쓰는 유저별 배치 진행 커서 조회를 실제 MySQL로 검증한다 (피라미드 3층). */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@ActiveProfiles("test")
class QuizProgressRepositoryTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private static final Long USER_ID = 1L;
    private static final Long OTHER_USER_ID = 2L;

    private final QuizProgressRepository quizProgressRepository;

    QuizProgressRepositoryTest(@Autowired QuizProgressRepository quizProgressRepository) {
        this.quizProgressRepository = quizProgressRepository;
    }

    @Nested
    @DisplayName("findByUserIdAndCourseIdIn")
    class FindByUserIdAndCourseIdIn {

        @Test
        @DisplayName("지정한 코스 목록 안에서만 그 유저의 진행 커서를 반환한다")
        void returns_progress_scoped_to_given_courses() {
            quizProgressRepository.save(QuizProgress.create(USER_ID, 1L, 5));
            quizProgressRepository.save(QuizProgress.create(USER_ID, 2L, 13));
            quizProgressRepository.save(QuizProgress.create(USER_ID, 3L, 20)); // 조회 대상 밖 코스

            List<QuizProgress> result = quizProgressRepository.findByUserIdAndCourseIdIn(USER_ID, List.of(1L, 2L));

            assertThat(result)
                    .extracting(QuizProgress::getCourseId, QuizProgress::getCurrentStepOrder)
                    .containsExactlyInAnyOrder(tuple(1L, 5), tuple(2L, 13));
        }

        @Test
        @DisplayName("다른 유저의 진행은 섞이지 않는다")
        void does_not_mix_other_users_progress() {
            quizProgressRepository.save(QuizProgress.create(USER_ID, 1L, 5));
            quizProgressRepository.save(QuizProgress.create(OTHER_USER_ID, 1L, 9));

            List<QuizProgress> result = quizProgressRepository.findByUserIdAndCourseIdIn(USER_ID, List.of(1L));

            assertThat(result).extracting(QuizProgress::getUserId).containsExactly(USER_ID);
        }

        @Test
        @DisplayName("빈 코스 목록으로 조회하면 빈 목록을 반환한다")
        void returns_empty_when_no_course_ids_given() {
            quizProgressRepository.save(QuizProgress.create(USER_ID, 1L, 5));

            List<QuizProgress> result = quizProgressRepository.findByUserIdAndCourseIdIn(USER_ID, List.of());

            assertThat(result).isEmpty();
        }
    }
}
