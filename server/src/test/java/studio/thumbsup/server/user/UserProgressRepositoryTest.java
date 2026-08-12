package studio.thumbsup.server.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalDate;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import studio.thumbsup.server.common.support.DatabaseCleanUp;
import studio.thumbsup.server.common.support.RepositoryTestSupport;

/**
 * Repository 통합 테스트 — 실제 MySQL(Testcontainers)에 Flyway 마이그레이션을 적용해
 * user_progress 저장·조회·제약을 검증한다 (피라미드 3층).
 */
class UserProgressRepositoryTest extends RepositoryTestSupport {

    private final UserProgressRepository userProgressRepository;
    private final DatabaseCleanUp databaseCleanUp;

    UserProgressRepositoryTest(
            @Autowired UserProgressRepository userProgressRepository, @Autowired DatabaseCleanUp databaseCleanUp) {
        this.userProgressRepository = userProgressRepository;
        this.databaseCleanUp = databaseCleanUp;
    }

    @BeforeEach
    void cleanSeedData() {
        databaseCleanUp.execute();
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

        @Test
        @DisplayName("완료일(lastCompletedDate)을 저장·조회한다")
        void persists_last_completed_date() {
            UserProgress progress = UserProgress.create(1L, 1, 0);
            progress.recordCompletion(LocalDate.of(2026, 7, 11));

            userProgressRepository.saveAndFlush(progress);

            Optional<UserProgress> found = userProgressRepository.findByUserId(1L);
            assertThat(found).isPresent();
            assertThat(found.get().getLastCompletedDate()).isEqualTo(LocalDate.of(2026, 7, 11));
        }
    }
}
