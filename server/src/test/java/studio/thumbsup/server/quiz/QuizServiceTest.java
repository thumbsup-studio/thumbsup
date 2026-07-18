package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.dto.AnswerSubmitRequest;
import studio.thumbsup.server.quiz.dto.AnswerSubmitResponse;
import studio.thumbsup.server.quiz.dto.QuizNextResponse;

@ExtendWith(MockitoExtension.class)
class QuizServiceTest {

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

    @Mock
    private UserProgressService userProgressService;

    private QuizService quizService;

    private static final Long USER_ID = 1L;
    private static final Instant NOW = Instant.parse("2026-07-11T00:00:00Z");

    private QuizService service() {
        return new QuizService(
                quizRepository,
                courseRepository,
                quizStepRepository,
                quizAttemptRepository,
                quizProgressRepository,
                userProgressService,
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private static Quiz quizWithId(Long id, int stepOrder, int slotOrder) {
        Quiz quiz = QuizFixture.oxQuiz();
        quiz.assignPosition(stepOrder, slotOrder);
        ReflectionTestUtils.setField(quiz, "id", id);
        return quiz;
    }

    @Nested
    @DisplayName("다음 문제 조회")
    class GetNextQuiz {

        @Test
        @DisplayName("진행 기록이 없으면 1스텝부터 시작한다")
        void starts_from_step_one_when_no_progress() {
            quizService = service();
            given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.empty());
            Quiz first = quizWithId(10L, 1, 1);
            given(quizRepository.findByStepOrderOrderBySlotOrderAsc(1)).willReturn(List.of(first));
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(List.of());

            QuizNextResponse response = quizService.getNextQuiz(USER_ID);

            assertThat(response.quizId()).isEqualTo(10L);
            assertThat(response.stepOrder()).isEqualTo(1);
        }

        @Test
        @DisplayName("이미 푼 문제는 건너뛰고 다음 순번 문제를 반환한다")
        void skips_already_attempted_quiz() {
            quizService = service();
            given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(QuizProgress.create(USER_ID)));

            Quiz attempted = quizWithId(10L, 1, 1);
            Quiz next = quizWithId(11L, 1, 2);
            given(quizRepository.findByStepOrderOrderBySlotOrderAsc(1)).willReturn(List.of(attempted, next));

            QuizAttempt attempt = QuizAttempt.create(attempted, USER_ID, true);
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(List.of(attempt));

            QuizNextResponse response = quizService.getNextQuiz(USER_ID);

            assertThat(response.quizId()).isEqualTo(11L);
        }

        @Test
        @DisplayName("오답으로 시도한 문제도 건너뛰고 다음 문제로 선형 진행한다")
        void skips_quiz_even_with_only_incorrect_attempt() {
            quizService = service();
            given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.empty());
            Quiz wrongAttempted = quizWithId(10L, 1, 1);
            Quiz next = quizWithId(11L, 1, 2);
            given(quizRepository.findByStepOrderOrderBySlotOrderAsc(1)).willReturn(List.of(wrongAttempted, next));
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(List.of(QuizAttempt.create(wrongAttempted, USER_ID, false)));

            QuizNextResponse response = quizService.getNextQuiz(USER_ID);

            assertThat(response.quizId()).isEqualTo(11L);
        }

        @Test
        @DisplayName("현재 스텝에 해당하는 문제가 없으면 QUIZ_NOT_FOUND")
        void throws_quiz_not_found_when_step_is_empty() {
            quizService = service();
            given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.empty());
            given(quizRepository.findByStepOrderOrderBySlotOrderAsc(1)).willReturn(List.of());

            assertThatThrownBy(() -> quizService.getNextQuiz(USER_ID))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(QuizErrorType.QUIZ_NOT_FOUND));
        }

        @Test
        @DisplayName("스텝의 문제를 모두 풀었으면 QUIZ_STEP_COMPLETED")
        void throws_step_completed_when_all_attempted() {
            quizService = service();
            given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.empty());
            Quiz only = quizWithId(10L, 1, 1);
            given(quizRepository.findByStepOrderOrderBySlotOrderAsc(1)).willReturn(List.of(only));
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(List.of(QuizAttempt.create(only, USER_ID, true)));

            assertThatThrownBy(() -> quizService.getNextQuiz(USER_ID))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(QuizErrorType.QUIZ_STEP_COMPLETED));
        }
    }

    @Nested
    @DisplayName("정답 제출")
    class SubmitAnswer {

        @Test
        @DisplayName("OX 정답이면 isCorrect=true를 반환한다")
        void grades_ox_correct() {
            quizService = service();
            Quiz quiz = quizWithId(10L, 1, 1); // oxQuiz — correctAnswer="O"
            given(quizRepository.findById(10L)).willReturn(Optional.of(quiz));
            given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(quiz.getId()));
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(List.of());

            AnswerSubmitResponse response =
                    quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O")));

            assertThat(response.isCorrect()).isTrue();
        }

        @Test
        @DisplayName("OX 오답이면 isCorrect=false를 반환한다")
        void grades_ox_incorrect() {
            quizService = service();
            Quiz quiz = quizWithId(10L, 1, 1);
            given(quizRepository.findById(10L)).willReturn(Optional.of(quiz));
            given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(quiz.getId()));
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(List.of());

            AnswerSubmitResponse response =
                    quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("X")));

            assertThat(response.isCorrect()).isFalse();
        }

        @Test
        @DisplayName("사지선다는 제출한 선택지 id가 정답 선택지인지로 판정한다")
        void grades_multiple_choice_by_choice_id() {
            quizService = service();
            Quiz quiz = QuizFixture.multipleChoiceQuiz();
            quiz.assignPosition(1, 1);
            ReflectionTestUtils.setField(quiz, "id", 20L);
            long choiceId = 100L;
            for (QuizChoice choice : quiz.getChoices()) {
                ReflectionTestUtils.setField(choice, "id", choiceId++);
            }
            QuizChoice correctChoice = quiz.getChoices().stream()
                    .filter(QuizChoice::isCorrect)
                    .findFirst()
                    .orElseThrow();
            given(quizRepository.findById(20L)).willReturn(Optional.of(quiz));
            given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(quiz.getId()));
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(List.of());

            AnswerSubmitResponse response = quizService.submitAnswer(
                    USER_ID, 20L, new AnswerSubmitRequest(List.of(String.valueOf(correctChoice.getId()))));

            assertThat(response.isCorrect()).isTrue();
        }

        @Test
        @DisplayName("사지선다는 숫자로 파싱되지 않는 선택지 id를 제출하면 오답으로 처리한다")
        void grades_multiple_choice_incorrect_when_choice_id_is_not_numeric() {
            quizService = service();
            Quiz quiz = QuizFixture.multipleChoiceQuiz();
            quiz.assignPosition(1, 1);
            ReflectionTestUtils.setField(quiz, "id", 20L);
            given(quizRepository.findById(20L)).willReturn(Optional.of(quiz));
            given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(quiz.getId()));
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(List.of());

            AnswerSubmitResponse response =
                    quizService.submitAnswer(USER_ID, 20L, new AnswerSubmitRequest(List.of("garbage")));

            assertThat(response.isCorrect()).isFalse();
        }

        @Test
        @DisplayName("스텝의 모든 문제를 한 번씩 시도했으면 다음 스텝으로 진행한다")
        void advances_progress_when_step_fully_attempted() {
            quizService = service();
            Quiz last = quizWithId(10L, 1, 5);
            List<Quiz> stepQuizzes = List.of(
                    quizWithId(6L, 1, 1), quizWithId(7L, 1, 2), quizWithId(8L, 1, 3), quizWithId(9L, 1, 4), last);
            given(quizRepository.findById(10L)).willReturn(Optional.of(last));
            given(quizRepository.findIdsByStepOrder(1))
                    .willReturn(stepQuizzes.stream().map(Quiz::getId).toList());
            List<QuizAttempt> allAttempted = stepQuizzes.stream()
                    .map(q -> QuizAttempt.create(q, USER_ID, true))
                    .toList();
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(allAttempted);
            given(quizProgressRepository.findByUserIdForUpdate(USER_ID))
                    .willReturn(Optional.of(QuizProgress.create(USER_ID)));

            quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O")));

            ArgumentCaptor<QuizProgress> captor = ArgumentCaptor.forClass(QuizProgress.class);
            verify(quizProgressRepository).save(captor.capture());
            assertThat(captor.getValue().getCurrentStepOrder()).isEqualTo(2);
        }

        @Test
        @DisplayName("최초로 스텝을 완료하면 진행 상태 행을 새로 만들어 다음 스텝으로 저장한다")
        void creates_progress_row_on_first_step_completion() {
            quizService = service();
            Quiz last = quizWithId(10L, 1, 5);
            List<Quiz> stepQuizzes = List.of(
                    quizWithId(6L, 1, 1), quizWithId(7L, 1, 2), quizWithId(8L, 1, 3), quizWithId(9L, 1, 4), last);
            given(quizRepository.findById(10L)).willReturn(Optional.of(last));
            given(quizRepository.findIdsByStepOrder(1))
                    .willReturn(stepQuizzes.stream().map(Quiz::getId).toList());
            List<QuizAttempt> allAttempted = stepQuizzes.stream()
                    .map(q -> QuizAttempt.create(q, USER_ID, true))
                    .toList();
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(allAttempted);
            given(quizProgressRepository.findByUserIdForUpdate(USER_ID)).willReturn(Optional.empty());
            given(quizProgressRepository.saveAndFlush(any())).willAnswer(invocation -> invocation.getArgument(0));

            quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O")));

            ArgumentCaptor<QuizProgress> captor = ArgumentCaptor.forClass(QuizProgress.class);
            verify(quizProgressRepository).save(captor.capture());
            assertThat(captor.getValue().getCurrentStepOrder()).isEqualTo(2);
        }

        @Test
        @DisplayName("아직 시도하지 않은 문제가 남아있으면 진행 상태를 갱신하지 않는다")
        void does_not_advance_progress_when_step_incomplete() {
            quizService = service();
            Quiz quiz = quizWithId(10L, 1, 1);
            given(quizRepository.findById(10L)).willReturn(Optional.of(quiz));
            given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(10L, 11L));
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(List.of());

            quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O")));

            verify(quizProgressRepository, never()).save(any());
        }

        @Test
        @DisplayName("존재하지 않는 퀴즈면 QUIZ_NOT_FOUND")
        void throws_quiz_not_found_when_quiz_missing() {
            quizService = service();
            given(quizRepository.findById(999L)).willReturn(Optional.empty());
            assertThatThrownBy(() -> quizService.submitAnswer(USER_ID, 999L, new AnswerSubmitRequest(List.of("O"))))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(QuizErrorType.QUIZ_NOT_FOUND));
        }

        @Test
        @DisplayName("아직 진행하지 않은 미래 스텝의 문제는 QUIZ_NOT_ACCESSIBLE")
        void throws_quiz_not_accessible_when_step_is_ahead_of_progress() {
            quizService = service();
            Quiz futureQuiz = quizWithId(10L, 2, 1);
            given(quizRepository.findById(10L)).willReturn(Optional.of(futureQuiz));
            given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(QuizProgress.create(USER_ID)));
            assertThatThrownBy(() -> quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O"))))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(QuizErrorType.QUIZ_NOT_ACCESSIBLE));
        }

        @Test
        @DisplayName("이미 지난 스텝의 문제는 복습을 위해 제출할 수 있다")
        void allows_submitting_for_a_past_step() {
            quizService = service();
            QuizProgress progress = QuizProgress.create(USER_ID);
            progress.advanceToNextStep(); // currentStepOrder=2
            Quiz pastQuiz = quizWithId(10L, 1, 1);
            given(quizRepository.findById(10L)).willReturn(Optional.of(pastQuiz));
            given(quizProgressRepository.findByUserId(USER_ID)).willReturn(Optional.of(progress));
            given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(pastQuiz.getId()));
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(List.of());
            AnswerSubmitResponse response =
                    quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O")));

            assertThat(response.isCorrect()).isTrue();
        }
    }
}
