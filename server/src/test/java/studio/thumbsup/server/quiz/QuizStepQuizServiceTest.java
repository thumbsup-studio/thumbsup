package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.BDDMockito.given;

import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.dto.QuizNextResponse;

/** QuizService#getStepQuiz(#151) 단위 테스트 — QuizServiceTest와 분리(Checkstyle FileLength). */
@ExtendWith(MockitoExtension.class)
class QuizStepQuizServiceTest {

    @Mock
    private QuizRepository quizRepository;

    @Mock
    private CourseRepository courseRepository;

    @Mock
    private QuizStepRepository quizStepRepository;

    @Mock
    private QuizAttemptRepository quizAttemptRepository;

    @Mock
    private QuizProgressRepository quizProgressRepository;

    private static final Long USER_ID = 1L;

    private QuizService service() {
        return new QuizService(
                quizRepository, courseRepository, quizStepRepository, quizAttemptRepository, quizProgressRepository);
    }

    private static Quiz quizWithId(Long id, int stepOrder, int slotOrder) {
        Quiz quiz = QuizFixture.oxQuiz();
        quiz.assignPosition(stepOrder, slotOrder);
        ReflectionTestUtils.setField(quiz, "id", id);
        return quiz;
    }

    @Nested
    @DisplayName("스텝 내 문제 재조회")
    class GetStepQuiz {

        @Test
        @DisplayName("시도 여부와 무관하게 지정한 슬롯의 문제를 반환한다")
        void returns_quiz_regardless_of_attempt_history() {
            given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(QuizProgress.create(USER_ID)));
            given(quizRepository.findByStepOrderAndSlotOrder(1, 3)).willReturn(Optional.of(quizWithId(30L, 1, 3)));

            QuizNextResponse response = service().getStepQuiz(USER_ID, 1, 3);

            assertThat(response.quizId()).isEqualTo(30L);
            assertThat(response.slotOrder()).isEqualTo(3);
        }

        @Test
        @DisplayName("현재 진행 스텝보다 미래 스텝이면 QUIZ_NOT_ACCESSIBLE")
        void throws_not_accessible_for_future_step() {
            given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.empty()); // currentStepOrder=1

            assertThatThrownBy(() -> service().getStepQuiz(USER_ID, 2, 1))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(QuizErrorType.QUIZ_NOT_ACCESSIBLE));
        }

        @Test
        @DisplayName("존재하지 않는 스텝·슬롯이면 QUIZ_NOT_FOUND")
        void throws_not_found_when_missing() {
            given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(QuizProgress.create(USER_ID)));
            given(quizRepository.findByStepOrderAndSlotOrder(1, 9)).willReturn(Optional.empty());

            assertThatThrownBy(() -> service().getStepQuiz(USER_ID, 1, 9))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(QuizErrorType.QUIZ_NOT_FOUND));
        }
    }
}
