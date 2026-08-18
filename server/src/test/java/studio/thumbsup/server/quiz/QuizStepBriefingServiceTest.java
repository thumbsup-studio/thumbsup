package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.BDDMockito.given;

import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.dto.QuizNextResponse;
import studio.thumbsup.server.quiz.dto.QuizStepBriefingResponse;

/** 브리핑 조회와 브리핑 이후 현재 스텝 문제 조회의 비즈니스 규칙을 검증한다. */
@ExtendWith(MockitoExtension.class)
class QuizStepBriefingServiceTest {

    private static final Long USER_ID = 7L;
    private static final Long COURSE_ID = 3L;
    private static final Long STEP_ID = 41L;

    @Mock
    private CourseRepository courseRepository;

    @Mock
    private QuizStepRepository quizStepRepository;

    @Mock
    private QuizProgressRepository quizProgressRepository;

    @Mock
    private QuizStepBriefingRepository briefingRepository;

    @Mock
    private QuizRepository quizRepository;

    @Mock
    private QuizAttemptRepository quizAttemptRepository;

    private QuizStepBriefingService service() {
        return new QuizStepBriefingService(
                courseRepository,
                quizStepRepository,
                quizProgressRepository,
                briefingRepository,
                quizRepository,
                quizAttemptRepository);
    }

    private static QuizStep step(long id, int stepOrder) {
        QuizStep step = QuizStep.create(stepOrder, COURSE_ID, "프로세스", 3);
        ReflectionTestUtils.setField(step, "id", id);
        return step;
    }

    private static Quiz quiz(long id, int slotOrder) {
        Quiz quiz = QuizFixture.oxQuiz();
        quiz.assignPosition(STEP_ID, 1, slotOrder);
        ReflectionTestUtils.setField(quiz, "id", id);
        return quiz;
    }

    private void givenCurrentStep(int stepOrder) {
        given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                .willReturn(Optional.of(QuizProgress.create(USER_ID, COURSE_ID, stepOrder)));
        given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(3));
    }

    @Nested
    @DisplayName("현재 스텝 브리핑 조회")
    class GetNextBriefing {

        @Test
        @DisplayName("현재 스텝의 요약과 순서 있는 블록을 반환한다")
        void returns_current_step_briefing() {
            QuizStep currentStep = step(STEP_ID, 1);
            QuizStepBriefing briefing = QuizStepBriefing.create(STEP_ID, "프로세스의 실행 단위를 정리합니다.");
            briefing.addBlock(QuizStepBriefingBlockType.CONCEPT, "핵심", "프로세스는 실행 중인 프로그램입니다.", 1);
            givenCurrentStep(1);
            given(quizStepRepository.findByCourseIdAndStepOrder(COURSE_ID, 1)).willReturn(Optional.of(currentStep));
            given(briefingRepository.findWithBlocksByQuizStepId(STEP_ID)).willReturn(Optional.of(briefing));

            QuizStepBriefingResponse response = service().getNextBriefing(USER_ID, COURSE_ID);

            assertThat(response.quizStepId()).isEqualTo(STEP_ID);
            assertThat(response.summary()).isEqualTo("프로세스의 실행 단위를 정리합니다.");
            assertThat(response.blocks())
                    .extracting(QuizStepBriefingResponse.Block::displayOrder)
                    .containsExactly(1);
        }

        @Test
        @DisplayName("현재 스텝에 브리핑이 없으면 준비되지 않음 오류를 반환한다")
        void throws_not_available_when_briefing_is_missing() {
            QuizStep currentStep = step(STEP_ID, 1);
            givenCurrentStep(1);
            given(quizStepRepository.findByCourseIdAndStepOrder(COURSE_ID, 1)).willReturn(Optional.of(currentStep));
            given(briefingRepository.findWithBlocksByQuizStepId(STEP_ID)).willReturn(Optional.empty());

            assertThatThrownBy(() -> service().getNextBriefing(USER_ID, COURSE_ID))
                    .isInstanceOf(BusinessException.class)
                    .extracting(error -> ((BusinessException) error).getErrorType())
                    .isEqualTo(QuizErrorType.QUIZ_STEP_BRIEFING_NOT_AVAILABLE);
        }
    }

    @Nested
    @DisplayName("브리핑 스텝의 다음 문제 조회")
    class GetNextQuizForStep {

        @Test
        @DisplayName("이미 시도한 문제를 건너뛰고 같은 스텝의 다음 문제를 반환한다")
        void skips_attempted_quiz_in_requested_step() {
            QuizStep currentStep = step(STEP_ID, 1);
            Quiz attempted = quiz(10L, 1);
            Quiz next = quiz(11L, 2);
            given(quizStepRepository.findById(STEP_ID)).willReturn(Optional.of(currentStep));
            givenCurrentStep(1);
            given(quizRepository.findByQuizStepIdOrderBySlotOrderAsc(STEP_ID)).willReturn(List.of(attempted, next));
            given(quizAttemptRepository.findByUserIdAndQuiz_QuizStepId(USER_ID, STEP_ID))
                    .willReturn(List.of(QuizAttempt.create(attempted, USER_ID, true)));

            QuizNextResponse response = service().getNextQuizForStep(USER_ID, STEP_ID);

            assertThat(response.quizId()).isEqualTo(11L);
            assertThat(response.slotOrder()).isEqualTo(2);
        }

        @Test
        @DisplayName("미래 스텝을 직접 지정하면 접근을 차단한다")
        void throws_not_accessible_for_future_step() {
            QuizStep futureStep = step(STEP_ID, 2);
            given(quizStepRepository.findById(STEP_ID)).willReturn(Optional.of(futureStep));
            givenCurrentStep(1);

            assertThatThrownBy(() -> service().getNextQuizForStep(USER_ID, STEP_ID))
                    .isInstanceOf(BusinessException.class)
                    .extracting(error -> ((BusinessException) error).getErrorType())
                    .isEqualTo(QuizErrorType.QUIZ_NOT_ACCESSIBLE);
        }

        @Test
        @DisplayName("이미 완료한 과거 스텝을 일반 학습으로 시작할 수 없다")
        void throws_not_current_for_past_step() {
            QuizStep completedStep = step(STEP_ID, 1);
            given(quizStepRepository.findById(STEP_ID)).willReturn(Optional.of(completedStep));
            givenCurrentStep(2);

            assertThatThrownBy(() -> service().getNextQuizForStep(USER_ID, STEP_ID))
                    .isInstanceOf(BusinessException.class)
                    .extracting(error -> ((BusinessException) error).getErrorType())
                    .isEqualTo(QuizErrorType.QUIZ_STEP_NOT_CURRENT);
        }
    }
}
