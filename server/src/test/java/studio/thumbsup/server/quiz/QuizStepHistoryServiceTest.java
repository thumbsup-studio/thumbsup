package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;

import java.time.Clock;
import java.time.Instant;
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
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.dto.QuizStepHistoryResponse;

/** QuizService#getCompletedSteps 단위 테스트 — QuizServiceTest와 분리(Checkstyle FileLength). */
@ExtendWith(MockitoExtension.class)
class QuizStepHistoryServiceTest {

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

    private static final Long USER_ID = 1L;
    private static final Long COURSE_ID = 1L;

    private QuizService service() {
        return new QuizService(
                quizRepository,
                courseRepository,
                quizStepRepository,
                quizAttemptRepository,
                quizProgressRepository,
                eventPublisher,
                Clock.fixed(Instant.parse("2026-07-11T00:00:00Z"), ZoneOffset.UTC));
    }

    @Nested
    @DisplayName("완료한 스텝 이력 조회")
    class GetCompletedSteps {

        @Test
        @DisplayName("진행 기록이 없으면(1스텝도 완료 전) 빈 목록을 반환한다")
        void returns_empty_when_no_progress() {
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.empty());
            given(quizStepRepository.findByCourseIdAndStepOrderBetweenOrderByStepOrderAsc(COURSE_ID, 1, 0))
                    .willReturn(List.of());

            QuizStepHistoryResponse response = service().getCompletedSteps(USER_ID, COURSE_ID);

            assertThat(response.steps()).isEmpty();
        }

        @Test
        @DisplayName("현재 진행 스텝보다 이전 스텝만 스텝번호·주제명으로 반환한다")
        void returns_completed_steps_before_current() {
            QuizProgress progress = QuizProgress.create(USER_ID, COURSE_ID, 1);
            progress.advanceToNextStep();
            progress.advanceToNextStep(); // currentStepOrder = 3 → 1,2스텝만 완료
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(progress));
            given(quizStepRepository.findByCourseIdAndStepOrderBetweenOrderByStepOrderAsc(COURSE_ID, 1, 2))
                    .willReturn(List.of(QuizStep.create(1, 1L, "프로세스와 스레드", 5), QuizStep.create(2, 1L, "CPU 스케줄링", 5)));

            QuizStepHistoryResponse response = service().getCompletedSteps(USER_ID, COURSE_ID);

            assertThat(response.steps()).hasSize(2);
            assertThat(response.steps())
                    .extracting(QuizStepHistoryResponse.Item::stepOrder)
                    .containsExactly(1, 2);
            assertThat(response.steps())
                    .extracting(QuizStepHistoryResponse.Item::topic)
                    .containsExactly("프로세스와 스레드", "CPU 스케줄링");
        }
    }
}
