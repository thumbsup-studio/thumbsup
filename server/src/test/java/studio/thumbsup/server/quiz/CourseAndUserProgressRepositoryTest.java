package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.DatabaseCleanUp;
import studio.thumbsup.server.common.config.ClockConfig;
import studio.thumbsup.server.common.config.JpaAuditingConfig;

/**
 * Repository 통합 테스트 — 실제 MySQL(Testcontainers)에 Flyway 마이그레이션을 적용해
 * course/user_progress 저장·조회·제약을 검증한다 (피라미드 3층). Unit은 #117에서 제거되었다
 * — "오늘의 화" 조회는 {@code QuizRepositoryTest}의 QuizStep 검증이 대신한다.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@Import({ClockConfig.class, JpaAuditingConfig.class, DatabaseCleanUp.class})
@ActiveProfiles("test")
class CourseAndUserProgressRepositoryTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final CourseRepository courseRepository;
    private final UserProgressRepository userProgressRepository;
    private final DatabaseCleanUp databaseCleanUp;

    CourseAndUserProgressRepositoryTest(
            @Autowired CourseRepository courseRepository,
            @Autowired UserProgressRepository userProgressRepository,
            @Autowired DatabaseCleanUp databaseCleanUp) {
        this.courseRepository = courseRepository;
        this.userProgressRepository = userProgressRepository;
        this.databaseCleanUp = databaseCleanUp;
    }

    // Flyway 시드가 course id=1("CS 기초")를 이미 커밋해 둔다 — "첫 코스" 같은 절대적 조건을 검증하는
    // 테스트가 시드와 충돌하지 않도록 각 테스트 실행 전 모든 테이블을 TRUNCATE해 독립적으로 검증한다.
    @BeforeEach
    void cleanSeedData() {
        databaseCleanUp.execute();
    }

    @Nested
    @DisplayName("코스 조회")
    class FindCourse {

        @Test
        @DisplayName("가장 먼저 생성된 코스를 기본 코스로 조회한다")
        void finds_first_course_as_default() {
            Course first = courseRepository.save(Course.create("CS 기초", "CS"));
            courseRepository.save(Course.create("두 번째 코스", "CS"));

            Optional<Course> defaultCourse = courseRepository.findFirstByOrderByIdAsc();

            assertThat(defaultCourse).isPresent();
            assertThat(defaultCourse.get().getId()).isEqualTo(first.getId());
        }
    }

    @Nested
    @DisplayName("유저 진행상태")
    class UserProgressPersistence {

        @Test
        @DisplayName("유저 기준으로 진행상태를 조회한다")
        void finds_progress_by_user_id() {
            userProgressRepository.saveAndFlush(UserProgress.create(1L, 5, 320));

            Optional<UserProgress> found = userProgressRepository.findByUserId(1L);

            assertThat(found).isPresent();
            assertThat(found.get().getStreak()).isEqualTo(5);
            assertThat(found.get().getPoints()).isEqualTo(320);
        }

        @Test
        @DisplayName("같은 유저는 중복 저장할 수 없다(unique 제약)")
        void rejects_duplicate_user_progress() {
            userProgressRepository.saveAndFlush(UserProgress.create(1L, 0, 0));

            assertThatThrownBy(() -> userProgressRepository.saveAndFlush(UserProgress.create(1L, 1, 10)))
                    .isInstanceOf(DataIntegrityViolationException.class);
        }
    }

    @Nested
    @DisplayName("감사 필드")
    class AuditFields {

        @Test
        @DisplayName("저장 시 자동으로 채워진다")
        void audit_fields_are_populated_on_save() {
            Course saved = courseRepository.save(Course.create("CS 기초", "CS"));

            assertThat(saved.getCreatedAt()).isNotNull();
            assertThat(saved.getUpdatedAt()).isNotNull();
        }
    }
}
