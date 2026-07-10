package studio.thumbsup.server.quiz;

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
}
