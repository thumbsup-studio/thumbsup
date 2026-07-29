package studio.thumbsup.server.user;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

class UserProgressTest {

    private static final Long USER_ID = 1L;

    @Nested
    @DisplayName("스텝 완료 기록")
    class RecordCompletion {

        @Test
        @DisplayName("처음 완료하면 스트릭을 1로 시작한다")
        void starts_streak_at_one_on_first_completion() {
            UserProgress progress = UserProgress.create(USER_ID, 0, 0);

            progress.recordCompletion(LocalDate.of(2026, 7, 11));

            assertThat(progress.getStreak()).isEqualTo(1);
            assertThat(progress.getLastCompletedDate()).isEqualTo(LocalDate.of(2026, 7, 11));
        }

        @Test
        @DisplayName("어제에 이어 오늘 완료하면 스트릭이 1 증가한다")
        void increments_streak_when_continued_from_yesterday() {
            UserProgress progress = UserProgress.create(USER_ID, 0, 0);
            progress.recordCompletion(LocalDate.of(2026, 7, 10));

            progress.recordCompletion(LocalDate.of(2026, 7, 11));

            assertThat(progress.getStreak()).isEqualTo(2);
        }

        @Test
        @DisplayName("같은 날 두 번 완료해도 스트릭은 그대로다(멱등)")
        void does_not_double_increment_on_same_day() {
            UserProgress progress = UserProgress.create(USER_ID, 0, 0);
            progress.recordCompletion(LocalDate.of(2026, 7, 11));

            progress.recordCompletion(LocalDate.of(2026, 7, 11));

            assertThat(progress.getStreak()).isEqualTo(1);
        }

        @Test
        @DisplayName("하루를 건너뛰고 완료하면 스트릭이 1로 리셋된다")
        void resets_streak_when_a_day_is_skipped() {
            UserProgress progress = UserProgress.create(USER_ID, 0, 0);
            progress.recordCompletion(LocalDate.of(2026, 7, 9));
            progress.recordCompletion(LocalDate.of(2026, 7, 10)); // streak=2로 연속

            progress.recordCompletion(LocalDate.of(2026, 7, 12)); // 7/11을 건너뜀

            assertThat(progress.getStreak()).isEqualTo(1);
            assertThat(progress.getLastCompletedDate()).isEqualTo(LocalDate.of(2026, 7, 12));
        }
    }

    @Nested
    @DisplayName("화면 표시용 유효 스트릭")
    class EffectiveStreak {

        @Test
        @DisplayName("한 번도 완료한 적 없으면 0을 반환한다")
        void returns_zero_when_never_completed() {
            UserProgress progress = UserProgress.create(USER_ID, 0, 0);

            assertThat(progress.getEffectiveStreak(LocalDate.of(2026, 7, 11))).isZero();
        }

        @Test
        @DisplayName("오늘 완료했으면 저장된 스트릭 그대로 반환한다")
        void returns_stored_streak_when_completed_today() {
            UserProgress progress = UserProgress.create(USER_ID, 0, 0);
            progress.recordCompletion(LocalDate.of(2026, 7, 11));

            assertThat(progress.getEffectiveStreak(LocalDate.of(2026, 7, 11))).isEqualTo(1);
        }

        @Test
        @DisplayName("어제 완료했으면(오늘 아직 안 풀었어도) 저장된 스트릭을 그대로 보여준다")
        void returns_stored_streak_when_completed_yesterday() {
            UserProgress progress = UserProgress.create(USER_ID, 0, 0);
            progress.recordCompletion(LocalDate.of(2026, 7, 10));

            assertThat(progress.getEffectiveStreak(LocalDate.of(2026, 7, 11))).isEqualTo(1);
        }

        @Test
        @DisplayName("이틀 이상 건너뛰었으면 화면에는 0으로 보여준다(DB 값은 그대로 둔다)")
        void returns_zero_when_streak_is_stale() {
            UserProgress progress = UserProgress.create(USER_ID, 0, 0);
            progress.recordCompletion(LocalDate.of(2026, 7, 9));

            int effective = progress.getEffectiveStreak(LocalDate.of(2026, 7, 11));

            assertThat(effective).isZero();
            assertThat(progress.getStreak()).isEqualTo(1);
        }
    }
}
