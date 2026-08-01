package studio.thumbsup.server.user;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.BDDMockito.willThrow;
import static org.mockito.Mockito.verify;

import java.time.LocalDate;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import studio.thumbsup.server.common.event.QuizStepCompletedEvent;

@ExtendWith(MockitoExtension.class)
class UserProgressEventListenerTest {

    @Mock
    private UserProgressService userProgressService;

    private static final Long USER_ID = 1L;
    private static final LocalDate TODAY = LocalDate.of(2026, 7, 11);

    private UserProgressEventListener listener() {
        return new UserProgressEventListener(userProgressService);
    }

    @Nested
    @DisplayName("스텝 완료 이벤트 처리")
    class OnQuizStepCompleted {

        @Test
        @DisplayName("이벤트의 userId·completedOn으로 스트릭 갱신을 위임한다")
        void delegates_to_user_progress_service() {
            listener().onQuizStepCompleted(new QuizStepCompletedEvent(USER_ID, TODAY, 1));

            verify(userProgressService).recordStepCompletion(USER_ID, TODAY);
        }

        @Test
        @DisplayName("스트릭 갱신이 실패해도 예외를 밖으로 전파하지 않는다(로그만 남김)")
        void swallows_exception_on_failure() {
            willThrow(new RuntimeException("db down"))
                    .given(userProgressService)
                    .recordStepCompletion(USER_ID, TODAY);

            assertThatCode(() -> listener().onQuizStepCompleted(new QuizStepCompletedEvent(USER_ID, TODAY, 1)))
                    .doesNotThrowAnyException();
        }
    }
}
