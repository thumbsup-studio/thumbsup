package studio.thumbsup.server.learning;

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
 * course/unit/user_progress 저장·조회·제약을 검증한다 (피라미드 3층).
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@Import({ClockConfig.class, JpaAuditingConfig.class, DatabaseCleanUp.class})
@ActiveProfiles("test")
class LearningRepositoryTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final CourseRepository courseRepository;
    private final UnitRepository unitRepository;
    private final UserProgressRepository userProgressRepository;
    private final DatabaseCleanUp databaseCleanUp;

    LearningRepositoryTest(
            @Autowired CourseRepository courseRepository,
            @Autowired UnitRepository unitRepository,
            @Autowired UserProgressRepository userProgressRepository,
            @Autowired DatabaseCleanUp databaseCleanUp) {
        this.courseRepository = courseRepository;
        this.unitRepository = unitRepository;
        this.userProgressRepository = userProgressRepository;
        this.databaseCleanUp = databaseCleanUp;
    }

    // Flyway 시드(V20260710021230)가 course id=1("CS 기초")·user_progress(user_id=1, course_id=1)를
    // 이미 커밋해 둔다 — "첫 코스"·"특정 user_id" 같은 절대적 조건을 검증하는 테스트가 시드와 충돌하지
    // 않도록 각 테스트 실행 전 모든 테이블을 TRUNCATE해 독립적으로 검증한다.
    @BeforeEach
    void cleanSeedData() {
        databaseCleanUp.execute();
    }

    @Nested
    @DisplayName("코스·화 저장")
    class SaveCourseAndUnits {

        @Test
        @DisplayName("화가 orderIndex 순서로 함께 저장된다")
        void saves_units_in_order() {
            Course course = Course.create("CS 기초", "CS");
            course.addUnit(1, "배열과 리스트", 3);
            course.addUnit(2, "스택과 큐", 3);
            Course saved = courseRepository.save(course);

            Course found = courseRepository.findById(saved.getId()).orElseThrow();
            assertThat(found.getUnits()).hasSize(2);
            assertThat(found.getUnits()).extracting(Unit::getOrderIndex).containsExactly(1, 2);
        }

        @Test
        @DisplayName("가장 먼저 생성된 코스를 기본 코스로 조회한다")
        void finds_first_course_as_default() {
            Course first = courseRepository.save(Course.create("CS 기초", "CS"));
            courseRepository.save(Course.create("두 번째 코스", "CS"));

            Optional<Course> defaultCourse = courseRepository.findFirstByOrderByIdAsc();

            assertThat(defaultCourse).isPresent();
            assertThat(defaultCourse.get().getId()).isEqualTo(first.getId());
        }

        @Test
        @DisplayName("자식 데이터(화)도 DB에서 함께 삭제된다(cascade)")
        void deleting_course_cascades_to_units() {
            Course course = Course.create("CS 기초", "CS");
            course.addUnit(1, "배열과 리스트", 3);
            Course saved = courseRepository.save(course);
            Long unitId = saved.getUnits().get(0).getId();

            courseRepository.delete(saved);
            courseRepository.flush();

            assertThat(unitRepository.findById(unitId)).isEmpty();
        }
    }

    @Nested
    @DisplayName("화 조회")
    class FindUnit {

        @Test
        @DisplayName("코스 내 특정 순번의 화를 조회한다")
        void finds_unit_by_course_and_order_index() {
            Course course = Course.create("CS 기초", "CS");
            course.addUnit(1, "배열과 리스트", 3);
            course.addUnit(2, "스택과 큐", 3);
            Course saved = courseRepository.save(course);

            Optional<Unit> found = unitRepository.findByCourseIdAndOrderIndex(saved.getId(), 2);

            assertThat(found).isPresent();
            assertThat(found.get().getTitle()).isEqualTo("스택과 큐");
        }

        @Test
        @DisplayName("코스의 전체 화 수를 센다")
        void counts_units_by_course() {
            Course course = Course.create("CS 기초", "CS");
            course.addUnit(1, "배열과 리스트", 3);
            course.addUnit(2, "스택과 큐", 3);
            course.addUnit(3, "해시 테이블", 3);
            Course saved = courseRepository.save(course);

            long count = unitRepository.countByCourseId(saved.getId());

            assertThat(count).isEqualTo(3);
        }
    }

    @Nested
    @DisplayName("유저 진행상태")
    class UserProgressPersistence {

        @Test
        @DisplayName("유저 기준으로 진행상태를 조회한다")
        void finds_progress_by_user_id() {
            userProgressRepository.saveAndFlush(UserProgress.create(1L, 1L, 3, 5, 320));

            Optional<UserProgress> found = userProgressRepository.findByUserId(1L);

            assertThat(found).isPresent();
            assertThat(found.get().getStreak()).isEqualTo(5);
            assertThat(found.get().getPoints()).isEqualTo(320);
        }

        @Test
        @DisplayName("같은 유저·코스 조합은 중복 저장할 수 없다(unique 제약)")
        void rejects_duplicate_user_course_progress() {
            userProgressRepository.saveAndFlush(UserProgress.create(1L, 1L, 1, 0, 0));

            assertThatThrownBy(() -> userProgressRepository.saveAndFlush(UserProgress.create(1L, 1L, 2, 1, 10)))
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
