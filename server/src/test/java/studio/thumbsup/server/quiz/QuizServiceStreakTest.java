package studio.thumbsup.server.quiz;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.event.QuizStepCompletedEvent;
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.dto.AnswerSubmitRequest;

/**
 * 정답 제출 시 스트릭(연속 학습) 기록 이벤트 발행 여부를 검증한다 — 스텝을 처음 완료했을 때만 오늘(KST) 날짜로 이벤트를 발행하는가.
 * 같은 서비스를 다루지만 {@code QuizServiceTest}에서 분리했다(checkstyle 파일 길이 상한 400줄).
 */
@ExtendWith(MockitoExtension.class)
class QuizServiceStreakTest {

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
    private ApplicationEventPublisher eventPublisher;

    private QuizService quizService;

    private static final Long USER_ID = 1L;
    private static final Long COURSE_ID = 1L;
    private static final Long QUIZ_STEP_ID = 1L;
    private static final Instant NOW = Instant.parse("2026-07-11T00:00:00Z");
    private static final LocalDate TODAY_KST = LocalDate.of(2026, 7, 11);

    private QuizService service() {
        return new QuizService(
                quizRepository,
                courseRepository,
                quizStepRepository,
                quizAttemptRepository,
                quizProgressRepository,
                eventPublisher,
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private static Quiz quizWithId(Long id, Long quizStepId, int stepOrder, int slotOrder) {
        Quiz quiz = QuizFixture.oxQuiz();
        quiz.assignPosition(quizStepId, stepOrder, slotOrder);
        ReflectionTestUtils.setField(quiz, "id", id);
        return quiz;
    }

    private static QuizStep stepFixture(int stepOrder) {
        return QuizStep.create(stepOrder, COURSE_ID, "토픽", 10);
    }

    @Nested
    @DisplayName("정답 제출 — 스트릭 기록")
    class SubmitAnswerStreak {

        @Test
        @DisplayName("스텝을 처음 완료하면 오늘(KST) 날짜로 스트릭 기록을 요청한다")
        void records_streak_when_step_first_completed() {
            quizService = service();
            Quiz last = quizWithId(10L, QUIZ_STEP_ID, 1, 5);
            List<Quiz> stepQuizzes = List.of(
                    quizWithId(6L, QUIZ_STEP_ID, 1, 1),
                    quizWithId(7L, QUIZ_STEP_ID, 1, 2),
                    quizWithId(8L, QUIZ_STEP_ID, 1, 3),
                    quizWithId(9L, QUIZ_STEP_ID, 1, 4),
                    last);
            given(quizRepository.findById(10L)).willReturn(Optional.of(last));
            given(quizStepRepository.findById(QUIZ_STEP_ID)).willReturn(Optional.of(stepFixture(1)));
            given(quizRepository.findIdsByQuizStepId(QUIZ_STEP_ID))
                    .willReturn(stepQuizzes.stream().map(Quiz::getId).toList());
            List<QuizAttempt> allAttempted = stepQuizzes.stream()
                    .map(q -> QuizAttempt.create(q, USER_ID, true))
                    .toList();
            given(quizAttemptRepository.findByUserIdAndQuiz_QuizStepId(USER_ID, QUIZ_STEP_ID))
                    .willReturn(allAttempted);
            QuizProgress progress = QuizProgress.create(USER_ID, COURSE_ID, 1);
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(progress));
            given(quizProgressRepository.findByUserIdAndCourseIdForUpdate(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(progress));

            quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O")));

            verify(eventPublisher).publishEvent(new QuizStepCompletedEvent(USER_ID, TODAY_KST, QUIZ_STEP_ID));
        }

        @Test
        @DisplayName("아직 시도하지 않은 문제가 남아있으면 스트릭 기록을 요청하지 않는다")
        void does_not_record_streak_when_step_incomplete() {
            quizService = service();
            Quiz quiz = quizWithId(10L, QUIZ_STEP_ID, 1, 1);
            given(quizRepository.findById(10L)).willReturn(Optional.of(quiz));
            given(quizStepRepository.findById(QUIZ_STEP_ID)).willReturn(Optional.of(stepFixture(1)));
            QuizProgress progress = QuizProgress.create(USER_ID, COURSE_ID, 1);
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(progress));
            given(quizProgressRepository.findByUserIdAndCourseIdForUpdate(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(progress));
            given(quizRepository.findIdsByQuizStepId(QUIZ_STEP_ID)).willReturn(List.of(10L, 11L));
            given(quizAttemptRepository.findByUserIdAndQuiz_QuizStepId(USER_ID, QUIZ_STEP_ID))
                    .willReturn(List.of());

            quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O")));

            verify(eventPublisher, never()).publishEvent(any(QuizStepCompletedEvent.class));
        }

        @Test
        @DisplayName("이미 지난 스텝을 복습으로 완료해도 진행·스트릭 갱신을 요청하지 않는다")
        void does_not_record_progress_or_streak_for_past_step_review_completion() {
            quizService = service();
            Quiz last = quizWithId(10L, QUIZ_STEP_ID, 1, 5);
            List<Quiz> stepQuizzes = List.of(
                    quizWithId(6L, QUIZ_STEP_ID, 1, 1),
                    quizWithId(7L, QUIZ_STEP_ID, 1, 2),
                    quizWithId(8L, QUIZ_STEP_ID, 1, 3),
                    quizWithId(9L, QUIZ_STEP_ID, 1, 4),
                    last);
            given(quizRepository.findById(10L)).willReturn(Optional.of(last));
            given(quizStepRepository.findById(QUIZ_STEP_ID)).willReturn(Optional.of(stepFixture(1)));
            given(quizRepository.findIdsByQuizStepId(QUIZ_STEP_ID))
                    .willReturn(stepQuizzes.stream().map(Quiz::getId).toList());
            List<QuizAttempt> allAttempted = stepQuizzes.stream()
                    .map(q -> QuizAttempt.create(q, USER_ID, true))
                    .toList();
            given(quizAttemptRepository.findByUserIdAndQuiz_QuizStepId(USER_ID, QUIZ_STEP_ID))
                    .willReturn(allAttempted);
            QuizProgress aheadProgress = QuizProgress.create(USER_ID, COURSE_ID, 1);
            aheadProgress.advanceToNextStep(); // currentStepOrder=2, 이미 스텝1을 지나감
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(aheadProgress));
            given(quizProgressRepository.findByUserIdAndCourseIdForUpdate(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(aheadProgress));

            quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O")));

            verify(quizProgressRepository, never()).save(any());
            verify(eventPublisher, never()).publishEvent(any(QuizStepCompletedEvent.class));
        }
    }
}
