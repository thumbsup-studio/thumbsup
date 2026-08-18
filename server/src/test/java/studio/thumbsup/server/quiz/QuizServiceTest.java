package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verifyNoInteractions;

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
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.course.CourseRepository;
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
    private ApplicationEventPublisher eventPublisher;

    private QuizService quizService;

    private static final Long USER_ID = 1L;
    private static final Long COURSE_ID = 1L;
    private static final Instant NOW = Instant.parse("2026-07-11T00:00:00Z");

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

    /** getNextQuiz는 quizStepRepository로 스텝을 별도 조회하므로(#292), 그 스텝의 PK를 반환값에 실어 둔다. */
    private static QuizStep stepWithId(Long id, int stepOrder, Long courseId) {
        QuizStep step = QuizStep.create(stepOrder, courseId, "토픽", 10);
        ReflectionTestUtils.setField(step, "id", id);
        return step;
    }

    @Nested
    @DisplayName("다음 문제 조회")
    class GetNextQuiz {

        @Test
        @DisplayName("진행 기록이 없으면 1스텝부터 시작한다")
        void starts_from_step_one_when_no_progress() {
            quizService = service();
            Long stepId = 100L;
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.empty());
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(12));
            given(quizStepRepository.findByCourseIdAndStepOrder(COURSE_ID, 1))
                    .willReturn(Optional.of(stepWithId(stepId, 1, COURSE_ID)));
            Quiz first = quizWithId(10L, stepId, 1, 1);
            given(quizRepository.findByQuizStepIdOrderBySlotOrderAsc(stepId)).willReturn(List.of(first));
            given(quizAttemptRepository.findByUserIdAndQuiz_QuizStepId(USER_ID, stepId))
                    .willReturn(List.of());

            QuizNextResponse response = quizService.getNextQuiz(USER_ID, COURSE_ID);

            assertThat(response.quizId()).isEqualTo(10L);
            assertThat(response.stepOrder()).isEqualTo(1);
        }

        @Test
        @DisplayName("이미 푼 문제는 건너뛰고 다음 순번 문제를 반환한다")
        void skips_already_attempted_quiz() {
            quizService = service();
            Long stepId = 100L;
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(QuizProgress.create(USER_ID, COURSE_ID, 1)));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(12));
            given(quizStepRepository.findByCourseIdAndStepOrder(COURSE_ID, 1))
                    .willReturn(Optional.of(stepWithId(stepId, 1, COURSE_ID)));

            Quiz attempted = quizWithId(10L, stepId, 1, 1);
            Quiz next = quizWithId(11L, stepId, 1, 2);
            given(quizRepository.findByQuizStepIdOrderBySlotOrderAsc(stepId)).willReturn(List.of(attempted, next));

            QuizAttempt attempt = QuizAttempt.create(attempted, USER_ID, true);
            given(quizAttemptRepository.findByUserIdAndQuiz_QuizStepId(USER_ID, stepId))
                    .willReturn(List.of(attempt));

            QuizNextResponse response = quizService.getNextQuiz(USER_ID, COURSE_ID);

            assertThat(response.quizId()).isEqualTo(11L);
        }

        @Test
        @DisplayName("스텝의 문제 수가 5가 아니어도 실제 개수를 totalCount로 반환한다")
        void returns_actual_step_size_as_total_count() {
            quizService = service();
            Long stepId = 100L;
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(QuizProgress.create(USER_ID, COURSE_ID, 1)));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(12));
            given(quizStepRepository.findByCourseIdAndStepOrder(COURSE_ID, 1))
                    .willReturn(Optional.of(stepWithId(stepId, 1, COURSE_ID)));
            given(quizRepository.findByQuizStepIdOrderBySlotOrderAsc(stepId))
                    .willReturn(List.of(
                            quizWithId(10L, stepId, 1, 1),
                            quizWithId(11L, stepId, 1, 2),
                            quizWithId(12L, stepId, 1, 3)));
            given(quizAttemptRepository.findByUserIdAndQuiz_QuizStepId(USER_ID, stepId))
                    .willReturn(List.of());

            QuizNextResponse response = quizService.getNextQuiz(USER_ID, COURSE_ID);

            assertThat(response.totalCount()).isEqualTo(3);
        }

        @Test
        @DisplayName("오답으로 시도한 문제도 건너뛰고 다음 문제로 선형 진행한다")
        void skips_quiz_even_with_only_incorrect_attempt() {
            quizService = service();
            Long stepId = 100L;
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.empty());
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(12));
            given(quizStepRepository.findByCourseIdAndStepOrder(COURSE_ID, 1))
                    .willReturn(Optional.of(stepWithId(stepId, 1, COURSE_ID)));
            Quiz wrongAttempted = quizWithId(10L, stepId, 1, 1);
            Quiz next = quizWithId(11L, stepId, 1, 2);
            given(quizRepository.findByQuizStepIdOrderBySlotOrderAsc(stepId)).willReturn(List.of(wrongAttempted, next));
            given(quizAttemptRepository.findByUserIdAndQuiz_QuizStepId(USER_ID, stepId))
                    .willReturn(List.of(QuizAttempt.create(wrongAttempted, USER_ID, false)));

            QuizNextResponse response = quizService.getNextQuiz(USER_ID, COURSE_ID);

            assertThat(response.quizId()).isEqualTo(11L);
        }

        @Test
        @DisplayName("현재 스텝에 해당하는 문제가 없으면 QUIZ_NOT_FOUND")
        void throws_quiz_not_found_when_step_is_empty() {
            quizService = service();
            Long stepId = 100L;
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.empty());
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(12));
            given(quizStepRepository.findByCourseIdAndStepOrder(COURSE_ID, 1))
                    .willReturn(Optional.of(stepWithId(stepId, 1, COURSE_ID)));
            given(quizRepository.findByQuizStepIdOrderBySlotOrderAsc(stepId)).willReturn(List.of());

            assertThatThrownBy(() -> quizService.getNextQuiz(USER_ID, COURSE_ID))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(QuizErrorType.QUIZ_NOT_FOUND));
        }

        @Test
        @DisplayName("스텝의 문제를 모두 풀었으면 QUIZ_STEP_COMPLETED")
        void throws_step_completed_when_all_attempted() {
            quizService = service();
            Long stepId = 100L;
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.empty());
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(12));
            given(quizStepRepository.findByCourseIdAndStepOrder(COURSE_ID, 1))
                    .willReturn(Optional.of(stepWithId(stepId, 1, COURSE_ID)));
            Quiz only = quizWithId(10L, stepId, 1, 1);
            given(quizRepository.findByQuizStepIdOrderBySlotOrderAsc(stepId)).willReturn(List.of(only));
            given(quizAttemptRepository.findByUserIdAndQuiz_QuizStepId(USER_ID, stepId))
                    .willReturn(List.of(QuizAttempt.create(only, USER_ID, true)));

            assertThatThrownBy(() -> quizService.getNextQuiz(USER_ID, COURSE_ID))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(QuizErrorType.QUIZ_STEP_COMPLETED));
        }

        @Test
        @DisplayName("같은 유저라도 코스가 다르면 진행 상태를 독립적으로 조회한다")
        void resolves_progress_independently_per_course() {
            quizService = service();
            Long otherCourseId = 2L;
            Long stepId = 100L;
            Long otherStepId = 200L;
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(QuizProgress.create(USER_ID, COURSE_ID, 1)));
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, otherCourseId))
                    .willReturn(Optional.of(QuizProgress.create(USER_ID, otherCourseId, 13)));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(12));
            given(quizStepRepository.findMaxStepOrderByCourseId(otherCourseId)).willReturn(Optional.of(14));
            given(quizStepRepository.findByCourseIdAndStepOrder(COURSE_ID, 1))
                    .willReturn(Optional.of(stepWithId(stepId, 1, COURSE_ID)));
            given(quizStepRepository.findByCourseIdAndStepOrder(otherCourseId, 13))
                    .willReturn(Optional.of(stepWithId(otherStepId, 13, otherCourseId)));

            Quiz courseAQuiz = quizWithId(10L, stepId, 1, 1);
            Quiz courseBQuiz = quizWithId(20L, otherStepId, 13, 1);
            given(quizRepository.findByQuizStepIdOrderBySlotOrderAsc(stepId)).willReturn(List.of(courseAQuiz));
            given(quizRepository.findByQuizStepIdOrderBySlotOrderAsc(otherStepId))
                    .willReturn(List.of(courseBQuiz));
            given(quizAttemptRepository.findByUserIdAndQuiz_QuizStepId(USER_ID, stepId))
                    .willReturn(List.of());
            given(quizAttemptRepository.findByUserIdAndQuiz_QuizStepId(USER_ID, otherStepId))
                    .willReturn(List.of());

            QuizNextResponse courseAResponse = quizService.getNextQuiz(USER_ID, COURSE_ID);
            QuizNextResponse courseBResponse = quizService.getNextQuiz(USER_ID, otherCourseId);

            assertThat(courseAResponse.stepOrder()).isEqualTo(1);
            assertThat(courseBResponse.stepOrder()).isEqualTo(13);
        }

        @Test
        @DisplayName("코스를 완주해 커서가 다음 코스의 stepOrder를 가리켜도 그 코스 문제를 내려주지 않고 QUIZ_STEP_COMPLETED를 던진다")
        void throws_step_completed_instead_of_leaking_next_course_when_cursor_past_max_step() {
            quizService = service();
            // OS 코스(1~12)를 완주해 커서가 13(디자인 패턴 코스의 stepOrder)이 된 상황을 재현한다.
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(QuizProgress.create(USER_ID, COURSE_ID, 13)));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(12));

            assertThatThrownBy(() -> quizService.getNextQuiz(USER_ID, COURSE_ID))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(QuizErrorType.QUIZ_STEP_COMPLETED));
            verifyNoInteractions(quizRepository);
        }
    }

    // "정답 제출" 테스트는 QuizServiceSubmitAnswerTest로 분리했다 — checkstyle FileLength(400줄) 제한.
}
