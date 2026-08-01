package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
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
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.event.QuizStepCompletedEvent;
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.dto.AnswerSubmitRequest;

/**
 * 스텝 완료 시 발행하는 {@link QuizStepCompletedEvent}의 {@code stepOrder}가 정확한지 검증한다(#233).
 * 이 이벤트를 구독해 지식 그래프 학습 기록을 남기는 쪽은 {@code concept.LearnedConceptRecorder}의
 * 소관이고, 스트릭 갱신 쪽은 이미 {@code QuizServiceStreakTest}가 검증하므로 여기서는 stepOrder 필드
 * 하나만 본다.
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("스텝 완료 이벤트의 stepOrder(#233)")
class QuizServiceLearnedConceptTest {

    private static final Long USER_ID = 1L;
    private static final Long COURSE_ID = 1L;
    private static final Instant NOW = Instant.parse("2026-07-11T00:00:00Z");

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

    private static Quiz quizWithId(Long id, int stepOrder, int slotOrder) {
        Quiz quiz = QuizFixture.oxQuiz();
        quiz.assignPosition(stepOrder, slotOrder);
        ReflectionTestUtils.setField(quiz, "id", id);
        return quiz;
    }

    private static QuizStep stepFixture(int stepOrder, Long courseId) {
        return QuizStep.create(stepOrder, courseId, "토픽", 10);
    }

    /** 스텝 1을 완료 직전 상태로 만든다 — 마지막 문제(10L)만 제출하면 스텝이 완료된다. */
    private void stubStepAboutToComplete() {
        Quiz last = quizWithId(10L, 1, 5);
        List<Quiz> stepQuizzes =
                List.of(quizWithId(6L, 1, 1), quizWithId(7L, 1, 2), quizWithId(8L, 1, 3), quizWithId(9L, 1, 4), last);
        given(quizRepository.findById(10L)).willReturn(Optional.of(last));
        given(quizStepRepository.findByStepOrder(1)).willReturn(Optional.of(stepFixture(1, COURSE_ID)));
        QuizProgress progress = QuizProgress.create(USER_ID, COURSE_ID, 1);
        given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                .willReturn(Optional.of(progress));
        given(quizProgressRepository.findByUserIdAndCourseIdForUpdate(USER_ID, COURSE_ID))
                .willReturn(Optional.of(progress));
        given(quizRepository.findIdsByStepOrder(1))
                .willReturn(stepQuizzes.stream().map(Quiz::getId).toList());
        List<QuizAttempt> allAttempted = stepQuizzes.stream()
                .map(q -> QuizAttempt.create(q, USER_ID, true))
                .toList();
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1)).willReturn(allAttempted);
    }

    @Test
    @DisplayName("스텝을 처음 완료하면 그 스텝 번호를 담아 이벤트를 발행한다")
    void publishes_event_with_step_order_on_first_step_completion() {
        quizService = service();
        stubStepAboutToComplete();

        quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O")));

        ArgumentCaptor<QuizStepCompletedEvent> captor = ArgumentCaptor.forClass(QuizStepCompletedEvent.class);
        verify(eventPublisher).publishEvent(captor.capture());
        assertThat(captor.getValue().userId()).isEqualTo(USER_ID);
        assertThat(captor.getValue().stepOrder()).isEqualTo(1);
    }

    @Test
    @DisplayName("스텝이 아직 완료되지 않았으면 이벤트를 발행하지 않는다")
    void does_not_publish_when_step_incomplete() {
        quizService = service();
        Quiz quiz = quizWithId(10L, 1, 1);
        given(quizRepository.findById(10L)).willReturn(Optional.of(quiz));
        given(quizStepRepository.findByStepOrder(1)).willReturn(Optional.of(stepFixture(1, COURSE_ID)));
        QuizProgress progress = QuizProgress.create(USER_ID, COURSE_ID, 1);
        given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                .willReturn(Optional.of(progress));
        given(quizProgressRepository.findByUserIdAndCourseIdForUpdate(USER_ID, COURSE_ID))
                .willReturn(Optional.of(progress));
        given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(10L, 11L)); // 11L 미시도
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1)).willReturn(List.of());

        quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O")));

        verify(eventPublisher, never()).publishEvent(any(QuizStepCompletedEvent.class));
    }

    @Test
    @DisplayName("이미 지난 스텝을 복습(재제출)해도 이벤트를 다시 발행하지 않는다")
    void does_not_publish_when_replaying_past_step() {
        quizService = service();
        QuizProgress progress = QuizProgress.create(USER_ID, COURSE_ID, 1);
        progress.advanceToNextStep(); // currentStepOrder=2, 스텝 1은 이미 완료됨
        Quiz pastQuiz = quizWithId(10L, 1, 1);
        given(quizRepository.findById(10L)).willReturn(Optional.of(pastQuiz));
        given(quizStepRepository.findByStepOrder(1)).willReturn(Optional.of(stepFixture(1, COURSE_ID)));
        given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                .willReturn(Optional.of(progress));
        given(quizProgressRepository.findByUserIdAndCourseIdForUpdate(USER_ID, COURSE_ID))
                .willReturn(Optional.of(progress));
        given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(pastQuiz.getId()));
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                .willReturn(List.of(QuizAttempt.create(pastQuiz, USER_ID, true)));

        quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O")));

        verify(eventPublisher, never()).publishEvent(any(QuizStepCompletedEvent.class));
    }
}
