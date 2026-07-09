package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.BDDMockito.given;

import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.dto.QuizNextResponse;

@ExtendWith(MockitoExtension.class)
@DisplayName("다음 문제 조회")
class QuizServiceGetNextQuizTest {

    @Mock
    private QuizRepository quizRepository;

    @Mock
    private QuizAttemptRepository quizAttemptRepository;

    @Mock
    private QuizProgressRepository quizProgressRepository;

    private static final Long USER_ID = 1L;

    private QuizService service() {
        return new QuizService(quizRepository, quizAttemptRepository, quizProgressRepository);
    }

    private static Quiz quizWithId(Long id, int stepOrder, int slotOrder) {
        Quiz quiz = QuizFixture.oxQuiz();
        quiz.assignPosition(stepOrder, slotOrder);
        ReflectionTestUtils.setField(quiz, "id", id);
        return quiz;
    }

    @Test
    @DisplayName("진행 기록이 없으면 1스텝부터 시작한다")
    void starts_from_step_one_when_no_progress() {
        QuizService quizService = service();
        given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.empty());
        Quiz first = quizWithId(10L, 1, 1);
        given(quizRepository.findByStepOrderOrderBySlotOrderAsc(1)).willReturn(List.of(first));
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1)).willReturn(List.of());

        QuizNextResponse response = quizService.getNextQuiz(USER_ID);

        assertThat(response.quizId()).isEqualTo(10L);
        assertThat(response.stepOrder()).isEqualTo(1);
    }

    @Test
    @DisplayName("이미 푼 문제는 건너뛰고 다음 순번 문제를 반환한다")
    void skips_already_attempted_quiz() {
        QuizService quizService = service();
        given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(QuizProgress.create(USER_ID)));

        Quiz attempted = quizWithId(10L, 1, 1);
        Quiz next = quizWithId(11L, 1, 2);
        given(quizRepository.findByStepOrderOrderBySlotOrderAsc(1)).willReturn(List.of(attempted, next));

        QuizAttempt attempt = QuizAttempt.create(attempted, USER_ID, true, "O");
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1)).willReturn(List.of(attempt));

        QuizNextResponse response = quizService.getNextQuiz(USER_ID);

        assertThat(response.quizId()).isEqualTo(11L);
    }

    @Test
    @DisplayName("오답으로 시도한 문제도 건너뛰고 다음 문제로 선형 진행한다")
    void skips_quiz_even_with_only_incorrect_attempt() {
        QuizService quizService = service();
        given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.empty());
        Quiz wrongAttempted = quizWithId(10L, 1, 1);
        Quiz next = quizWithId(11L, 1, 2);
        given(quizRepository.findByStepOrderOrderBySlotOrderAsc(1)).willReturn(List.of(wrongAttempted, next));
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                .willReturn(List.of(QuizAttempt.create(wrongAttempted, USER_ID, false, "X")));

        QuizNextResponse response = quizService.getNextQuiz(USER_ID);

        assertThat(response.quizId()).isEqualTo(11L);
    }

    @Test
    @DisplayName("현재 스텝에 해당하는 문제가 없으면 QUIZ_NOT_FOUND")
    void throws_quiz_not_found_when_step_is_empty() {
        QuizService quizService = service();
        given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.empty());
        given(quizRepository.findByStepOrderOrderBySlotOrderAsc(1)).willReturn(List.of());

        assertThatThrownBy(() -> quizService.getNextQuiz(USER_ID))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex ->
                        assertThat(((BusinessException) ex).getErrorType()).isEqualTo(QuizErrorType.QUIZ_NOT_FOUND));
    }

    @Test
    @DisplayName("스텝의 문제를 모두 풀었으면 QUIZ_STEP_COMPLETED")
    void throws_step_completed_when_all_attempted() {
        QuizService quizService = service();
        given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.empty());
        Quiz only = quizWithId(10L, 1, 1);
        given(quizRepository.findByStepOrderOrderBySlotOrderAsc(1)).willReturn(List.of(only));
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                .willReturn(List.of(QuizAttempt.create(only, USER_ID, true, "O")));

        assertThatThrownBy(() -> quizService.getNextQuiz(USER_ID))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                        .isEqualTo(QuizErrorType.QUIZ_STEP_COMPLETED));
    }
}
