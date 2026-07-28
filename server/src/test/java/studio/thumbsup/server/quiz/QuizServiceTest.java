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
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.exception.BusinessException;
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
    private static final Long COURSE_ID = 1L;
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
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.empty());
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(12));
            Quiz first = quizWithId(10L, 1, 1);
            given(quizRepository.findByStepOrderOrderBySlotOrderAsc(1)).willReturn(List.of(first));
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(List.of());

            QuizNextResponse response = quizService.getNextQuiz(USER_ID, COURSE_ID);

            assertThat(response.quizId()).isEqualTo(10L);
            assertThat(response.stepOrder()).isEqualTo(1);
        }

        @Test
        @DisplayName("이미 푼 문제는 건너뛰고 다음 순번 문제를 반환한다")
        void skips_already_attempted_quiz() {
            quizService = service();
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(QuizProgress.create(USER_ID, COURSE_ID, 1)));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(12));

            Quiz attempted = quizWithId(10L, 1, 1);
            Quiz next = quizWithId(11L, 1, 2);
            given(quizRepository.findByStepOrderOrderBySlotOrderAsc(1)).willReturn(List.of(attempted, next));

            QuizAttempt attempt = QuizAttempt.create(attempted, USER_ID, true);
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(List.of(attempt));

            QuizNextResponse response = quizService.getNextQuiz(USER_ID, COURSE_ID);

            assertThat(response.quizId()).isEqualTo(11L);
        }

        @Test
        @DisplayName("오답으로 시도한 문제도 건너뛰고 다음 문제로 선형 진행한다")
        void skips_quiz_even_with_only_incorrect_attempt() {
            quizService = service();
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.empty());
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(12));
            Quiz wrongAttempted = quizWithId(10L, 1, 1);
            Quiz next = quizWithId(11L, 1, 2);
            given(quizRepository.findByStepOrderOrderBySlotOrderAsc(1)).willReturn(List.of(wrongAttempted, next));
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(List.of(QuizAttempt.create(wrongAttempted, USER_ID, false)));

            QuizNextResponse response = quizService.getNextQuiz(USER_ID, COURSE_ID);

            assertThat(response.quizId()).isEqualTo(11L);
        }

        @Test
        @DisplayName("현재 스텝에 해당하는 문제가 없으면 QUIZ_NOT_FOUND")
        void throws_quiz_not_found_when_step_is_empty() {
            quizService = service();
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.empty());
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(12));
            given(quizRepository.findByStepOrderOrderBySlotOrderAsc(1)).willReturn(List.of());

            assertThatThrownBy(() -> quizService.getNextQuiz(USER_ID, COURSE_ID))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                            .isEqualTo(QuizErrorType.QUIZ_NOT_FOUND));
        }

        @Test
        @DisplayName("스텝의 문제를 모두 풀었으면 QUIZ_STEP_COMPLETED")
        void throws_step_completed_when_all_attempted() {
            quizService = service();
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.empty());
            given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(12));
            Quiz only = quizWithId(10L, 1, 1);
            given(quizRepository.findByStepOrderOrderBySlotOrderAsc(1)).willReturn(List.of(only));
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
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
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                    .willReturn(Optional.of(QuizProgress.create(USER_ID, COURSE_ID, 1)));
            given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, otherCourseId))
                    .willReturn(Optional.of(QuizProgress.create(USER_ID, otherCourseId, 13)));
            given(quizStepRepository.findMaxStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(12));
            given(quizStepRepository.findMaxStepOrderByCourseId(otherCourseId)).willReturn(Optional.of(14));

            Quiz courseAQuiz = quizWithId(10L, 1, 1);
            Quiz courseBQuiz = quizWithId(20L, 13, 1);
            given(quizRepository.findByStepOrderOrderBySlotOrderAsc(1)).willReturn(List.of(courseAQuiz));
            given(quizRepository.findByStepOrderOrderBySlotOrderAsc(13)).willReturn(List.of(courseBQuiz));
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1))
                    .willReturn(List.of());
            given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 13))
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
