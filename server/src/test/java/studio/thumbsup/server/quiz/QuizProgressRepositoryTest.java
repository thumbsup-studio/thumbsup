package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.tuple;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import javax.sql.DataSource;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.config.ClockConfig;
import studio.thumbsup.server.common.config.JpaAuditingConfig;

/**
 * Repository 통합 테스트 — 코스 목록 조회(#247)의 배치 진행 커서 조회와 홈(#240)의 최근 푼 순 조회를
 * 실제 MySQL로 검증한다 (피라미드 3층).
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@Import({ClockConfig.class, JpaAuditingConfig.class})
@ActiveProfiles("test")
class QuizProgressRepositoryTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private static final Long USER_ID = 1L;
    private static final Long OTHER_USER_ID = 2L;

    private final QuizProgressRepository quizProgressRepository;
    private final JdbcTemplate jdbcTemplate;

    QuizProgressRepositoryTest(
            @Autowired QuizProgressRepository quizProgressRepository, @Autowired DataSource dataSource) {
        this.quizProgressRepository = quizProgressRepository;
        this.jdbcTemplate = new JdbcTemplate(dataSource);
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

    @Nested
    @DisplayName("findTop10ByUserIdOrderByUpdatedAtDescIdDesc")
    class FindTop10ByUserIdOrderByUpdatedAtDescIdDesc {

        private static final Instant BASE = Instant.parse("2026-08-01T00:00:00Z");

        /**
         * 저장(auditing) 시각에 의존하면 순서가 비결정적이라, updated_at을 SQL로 직접 박아 정렬 기준을
         * 통제한다 — save 후 flush로 INSERT를 내보낸 뒤에 호출할 것. 정렬은 DB가 수행하므로 영속성
         * 컨텍스트의 낡은 updatedAt 값은 결과 순서에 영향이 없다.
         */
        private void fixUpdatedAt(Long userId, Long courseId, Instant updatedAt) {
            jdbcTemplate.update(
                    "UPDATE quiz_progress SET updated_at = ? WHERE user_id = ? AND course_id = ?",
                    Timestamp.from(updatedAt),
                    userId,
                    courseId);
        }

        @Test
        @DisplayName("updatedAt이 최근인 진행(마지막으로 스텝을 완료한 코스)부터 반환한다")
        void returns_progress_ordered_by_updated_at_desc() {
            quizProgressRepository.save(QuizProgress.create(USER_ID, 1L, 5));
            quizProgressRepository.save(QuizProgress.create(USER_ID, 2L, 13));
            quizProgressRepository.save(QuizProgress.create(USER_ID, 3L, 20));
            quizProgressRepository.flush();
            fixUpdatedAt(USER_ID, 1L, BASE.plusSeconds(60)); // 가장 오래됨
            fixUpdatedAt(USER_ID, 2L, BASE.plusSeconds(180)); // 가장 최근
            fixUpdatedAt(USER_ID, 3L, BASE.plusSeconds(120));

            List<QuizProgress> result = quizProgressRepository.findTop10ByUserIdOrderByUpdatedAtDescIdDesc(USER_ID);

            assertThat(result).extracting(QuizProgress::getCourseId).containsExactly(2L, 3L, 1L);
        }

        @Test
        @DisplayName("진행 중인 코스가 10개를 넘으면 가장 오래된 것을 빼고 10개만 반환한다")
        void caps_result_at_ten_most_recent() {
            for (long courseId = 1; courseId <= 11; courseId++) {
                quizProgressRepository.save(QuizProgress.create(USER_ID, courseId, 1));
            }
            quizProgressRepository.flush();
            for (long courseId = 1; courseId <= 11; courseId++) {
                fixUpdatedAt(USER_ID, courseId, BASE.plusSeconds(courseId * 60)); // courseId 클수록 최근
            }

            List<QuizProgress> result = quizProgressRepository.findTop10ByUserIdOrderByUpdatedAtDescIdDesc(USER_ID);

            assertThat(result).hasSize(10);
            assertThat(result)
                    .extracting(QuizProgress::getCourseId)
                    .containsExactly(11L, 10L, 9L, 8L, 7L, 6L, 5L, 4L, 3L, 2L);
        }

        @Test
        @DisplayName("updatedAt이 같으면 나중에 시작한 진행(id 큰 쪽)을 앞세운다")
        void breaks_tie_by_id_desc() {
            quizProgressRepository.save(QuizProgress.create(USER_ID, 1L, 5));
            quizProgressRepository.save(QuizProgress.create(USER_ID, 2L, 13));
            quizProgressRepository.flush();
            fixUpdatedAt(USER_ID, 1L, BASE);
            fixUpdatedAt(USER_ID, 2L, BASE);

            List<QuizProgress> result = quizProgressRepository.findTop10ByUserIdOrderByUpdatedAtDescIdDesc(USER_ID);

            assertThat(result).extracting(QuizProgress::getCourseId).containsExactly(2L, 1L);
        }

        @Test
        @DisplayName("다른 유저의 진행은 섞이지 않는다")
        void does_not_mix_other_users_progress() {
            quizProgressRepository.save(QuizProgress.create(USER_ID, 1L, 5));
            quizProgressRepository.save(QuizProgress.create(OTHER_USER_ID, 2L, 9));
            quizProgressRepository.flush();
            fixUpdatedAt(USER_ID, 1L, BASE);
            fixUpdatedAt(OTHER_USER_ID, 2L, BASE.plusSeconds(600)); // 남의 진행이 더 최근이어도

            List<QuizProgress> result = quizProgressRepository.findTop10ByUserIdOrderByUpdatedAtDescIdDesc(USER_ID);

            assertThat(result).extracting(QuizProgress::getUserId).containsExactly(USER_ID);
        }
    }
}
