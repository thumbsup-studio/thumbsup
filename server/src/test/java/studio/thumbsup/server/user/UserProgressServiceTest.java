package studio.thumbsup.server.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;

import java.time.LocalDate;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.user.UserProgressSnapshot;

@ExtendWith(MockitoExtension.class)
class UserProgressServiceTest {

    @Mock
    private UserProgressRepository userProgressRepository;

    private static final Long USER_ID = 1L;

    private UserProgressService service() {
        return new UserProgressService(userProgressRepository);
    }

    @Nested
    @DisplayName("스텝 완료 기록")
    class RecordStepCompletion {

        @Test
        @DisplayName("기존 진행 상태가 있으면 그 행에 완료를 기록하고 저장한다")
        void records_completion_on_existing_progress() {
            UserProgress progress = UserProgress.create(USER_ID, 3, 0);
            progress.recordCompletion(LocalDate.of(2026, 7, 10));
            given(userProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(progress));

            service().recordStepCompletion(USER_ID, LocalDate.of(2026, 7, 11));

            ArgumentCaptor<UserProgress> captor = ArgumentCaptor.forClass(UserProgress.class);
            verify(userProgressRepository).save(captor.capture());
            assertThat(captor.getValue().getStreak()).isEqualTo(2);
            assertThat(captor.getValue().getLastCompletedDate()).isEqualTo(LocalDate.of(2026, 7, 11));
        }

        @Test
        @DisplayName("진행 상태 행이 없으면(최초 완료) 새로 만들어 저장한다")
        void creates_progress_row_on_first_completion() {
            given(userProgressRepository.findByUserId(USER_ID)).willReturn(Optional.empty());

            service().recordStepCompletion(USER_ID, LocalDate.of(2026, 7, 11));

            ArgumentCaptor<UserProgress> captor = ArgumentCaptor.forClass(UserProgress.class);
            verify(userProgressRepository).save(captor.capture());
            assertThat(captor.getValue().getUserId()).isEqualTo(USER_ID);
            assertThat(captor.getValue().getStreak()).isEqualTo(1);
        }
    }

    @Nested
    @DisplayName("화면 표시용 스냅샷 조회")
    class GetSnapshot {

        @Test
        @DisplayName("진행 기록이 없으면 streak 0·points 0·todayCompleted false를 반환한다")
        void returns_empty_snapshot_when_no_progress() {
            given(userProgressRepository.findByUserId(USER_ID)).willReturn(Optional.empty());

            UserProgressSnapshot snapshot = service().getSnapshot(USER_ID, LocalDate.of(2026, 7, 11));

            assertThat(snapshot).isEqualTo(UserProgressSnapshot.empty());
        }

        @Test
        @DisplayName("오늘 이미 완료했으면 todayCompleted=true, 저장된 스트릭 그대로 반환한다")
        void returns_today_completed_true_when_completed_today() {
            UserProgress progress = progressFixture(5, 320, LocalDate.of(2026, 7, 11));
            given(userProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(progress));

            UserProgressSnapshot snapshot = service().getSnapshot(USER_ID, LocalDate.of(2026, 7, 11));

            assertThat(snapshot.streak()).isEqualTo(5);
            assertThat(snapshot.points()).isEqualTo(320);
            assertThat(snapshot.todayCompleted()).isTrue();
        }

        @Test
        @DisplayName("어제 완료하고 오늘은 아직이면 todayCompleted=false지만 스트릭은 유지된다")
        void returns_today_completed_false_when_not_completed_today() {
            UserProgress progress = progressFixture(5, 320, LocalDate.of(2026, 7, 10));
            given(userProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(progress));

            UserProgressSnapshot snapshot = service().getSnapshot(USER_ID, LocalDate.of(2026, 7, 11));

            assertThat(snapshot.todayCompleted()).isFalse();
            assertThat(snapshot.streak()).isEqualTo(5);
        }

        @Test
        @DisplayName("이틀 이상 스트릭이 끊겼으면 streak을 0으로 보여준다(DB 값은 그대로 둔다)")
        void returns_zero_streak_when_stale() {
            UserProgress progress = progressFixture(7, 320, LocalDate.of(2026, 7, 8));
            given(userProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(progress));

            UserProgressSnapshot snapshot = service().getSnapshot(USER_ID, LocalDate.of(2026, 7, 11));

            assertThat(snapshot.streak()).isZero();
            assertThat(snapshot.todayCompleted()).isFalse();
        }

        private UserProgress progressFixture(int streak, int points, LocalDate lastCompletedDate) {
            UserProgress progress = UserProgress.create(USER_ID, streak, points);
            ReflectionTestUtils.setField(progress, "lastCompletedDate", lastCompletedDate);
            return progress;
        }
    }
}
