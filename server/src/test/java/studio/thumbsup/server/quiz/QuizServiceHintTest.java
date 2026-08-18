package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.dto.QuizHintResponse;

@ExtendWith(MockitoExtension.class)
class QuizServiceHintTest {

    private static final Long USER_ID = 7L;
    private static final Long COURSE_ID = 1L;
    private static final Long QUIZ_ID = 30L;

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

    private QuizService service() {
        return new QuizService(
                quizRepository,
                courseRepository,
                quizStepRepository,
                quizAttemptRepository,
                quizProgressRepository,
                eventPublisher,
                Clock.fixed(Instant.parse("2026-07-31T00:00:00Z"), ZoneOffset.UTC));
    }

    private Quiz quizAtStep(int stepOrder) {
        Long quizStepId = (long) stepOrder;
        Quiz quiz = QuizFixture.oxQuiz();
        quiz.assignPosition(quizStepId, stepOrder, 1);
        ReflectionTestUtils.setField(quiz, "id", QUIZ_ID);
        given(quizRepository.findById(QUIZ_ID)).willReturn(Optional.of(quiz));
        given(quizStepRepository.findById(quizStepId))
                .willReturn(Optional.of(QuizStep.create(stepOrder, COURSE_ID, "토픽", 3)));
        return quiz;
    }

    @Nested
    @DisplayName("풀이 중 힌트 요청")
    class GetHint {

        @Test
        @DisplayName("접근 가능한 문제는 한 문장 힌트를 반환하고 풀이 상태를 변경하지 않는다")
        void returns_hint_without_mutating_attempt_or_progress() {
            Quiz quiz = quizAtStep(1);
            QuizProgress progress = QuizProgress.create(USER_ID, COURSE_ID, 1);
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(progress));

            QuizHintResponse response = service().getHint(USER_ID, QUIZ_ID);

            assertThat(response.hint()).isEqualTo(quiz.getHint());
            verifyNoInteractions(quizAttemptRepository, eventPublisher);
            verify(quizProgressRepository, never()).save(progress);
        }

        @Test
        @DisplayName("점진 백필에서 hint가 없는 문제는 409용 도메인 오류로 거부한다")
        void rejects_quiz_without_backfilled_hint() {
            Quiz quiz = quizAtStep(1);
            quiz.assignHint(null);
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(QuizProgress.create(USER_ID, COURSE_ID, 1)));

            assertThatThrownBy(() -> service().getHint(USER_ID, QUIZ_ID))
                    .isInstanceOf(BusinessException.class)
                    .extracting(ex -> ((BusinessException) ex).getErrorType())
                    .isEqualTo(QuizErrorType.QUIZ_HINT_NOT_AVAILABLE);

            verifyNoInteractions(quizAttemptRepository, eventPublisher);
        }

        @Test
        @DisplayName("아직 진행하지 않은 미래 스텝 문제는 거부한다")
        void rejects_future_step() {
            quizAtStep(2);
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(QuizProgress.create(USER_ID, COURSE_ID, 1)));

            assertThatThrownBy(() -> service().getHint(USER_ID, QUIZ_ID))
                    .isInstanceOf(BusinessException.class)
                    .extracting(ex -> ((BusinessException) ex).getErrorType())
                    .isEqualTo(QuizErrorType.QUIZ_NOT_ACCESSIBLE);
        }
    }
}
