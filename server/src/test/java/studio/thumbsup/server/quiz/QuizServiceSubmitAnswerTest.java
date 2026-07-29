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
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.dto.AnswerSubmitRequest;
import studio.thumbsup.server.quiz.dto.AnswerSubmitResponse;

/** {@link QuizServiceTest}에서 분리 — 파일당 400줄 제한(checkstyle FileLength)에 맞춰 "정답 제출" 관련 테스트만 모았다. */
@ExtendWith(MockitoExtension.class)
@DisplayName("정답 제출")
class QuizServiceSubmitAnswerTest {

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

    private static Quiz quizWithId(Long id, int stepOrder, int slotOrder) {
        Quiz quiz = QuizFixture.oxQuiz();
        quiz.assignPosition(stepOrder, slotOrder);
        ReflectionTestUtils.setField(quiz, "id", id);
        return quiz;
    }

    private static QuizStep stepFixture(int stepOrder, Long courseId) {
        return QuizStep.create(stepOrder, courseId, "토픽", 10);
    }

    /** 그 스텝이 courseId 코스에 속하고, 유저의 현재 진행 스텝도 그 스텝이라 접근·진행 갱신이 가능한 상태를 만든다. */
    private void stubSubmittableStep(int stepOrder) {
        given(quizStepRepository.findByStepOrder(stepOrder)).willReturn(Optional.of(stepFixture(stepOrder, COURSE_ID)));
        QuizProgress progress = QuizProgress.create(USER_ID, COURSE_ID, stepOrder);
        given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                .willReturn(Optional.of(progress));
        given(quizProgressRepository.findByUserIdAndCourseIdForUpdate(USER_ID, COURSE_ID))
                .willReturn(Optional.of(progress));
    }

    @Test
    @DisplayName("OX 정답이면 isCorrect=true를 반환한다")
    void grades_ox_correct() {
        quizService = service();
        Quiz quiz = quizWithId(10L, 1, 1); // oxQuiz — correctAnswer="O"
        given(quizRepository.findById(10L)).willReturn(Optional.of(quiz));
        stubSubmittableStep(1);
        given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(quiz.getId()));
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1)).willReturn(List.of());

        AnswerSubmitResponse response = quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O")));

        assertThat(response.isCorrect()).isTrue();
    }

    @Test
    @DisplayName("OX 오답이면 isCorrect=false를 반환한다")
    void grades_ox_incorrect() {
        quizService = service();
        Quiz quiz = quizWithId(10L, 1, 1);
        given(quizRepository.findById(10L)).willReturn(Optional.of(quiz));
        stubSubmittableStep(1);
        given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(quiz.getId()));
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1)).willReturn(List.of());

        AnswerSubmitResponse response = quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("X")));

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
        stubSubmittableStep(1);
        given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(quiz.getId()));
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1)).willReturn(List.of());

        AnswerSubmitResponse response = quizService.submitAnswer(
                USER_ID, 20L, new AnswerSubmitRequest(List.of(String.valueOf(correctChoice.getId()))));

        assertThat(response.isCorrect()).isTrue();
    }

    @Test
    @DisplayName("키워드 빈칸은 슬롯 순서대로 대소문자·공백을 무시하고 비교한다")
    void grades_keyword_blank_ignoring_case_and_whitespace() {
        quizService = service();
        Quiz quiz = QuizFixture.keywordBlankQuiz(); // answerKeywords = ["LIFO"]
        quiz.assignPosition(1, 1);
        ReflectionTestUtils.setField(quiz, "id", 30L);
        given(quizRepository.findById(30L)).willReturn(Optional.of(quiz));
        stubSubmittableStep(1);
        given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(quiz.getId()));
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1)).willReturn(List.of());

        AnswerSubmitResponse response =
                quizService.submitAnswer(USER_ID, 30L, new AnswerSubmitRequest(List.of("  lifo  ")));

        assertThat(response.isCorrect()).isTrue();
    }

    @Test
    @DisplayName("키워드 빈칸은 제출 개수가 정답 개수와 다르면 오답으로 처리한다")
    void grades_keyword_blank_incorrect_when_answer_count_mismatches() {
        quizService = service();
        Quiz quiz = QuizFixture.keywordBlankQuiz(); // answerKeywords = ["LIFO"] (1개)
        quiz.assignPosition(1, 1);
        ReflectionTestUtils.setField(quiz, "id", 30L);
        given(quizRepository.findById(30L)).willReturn(Optional.of(quiz));
        stubSubmittableStep(1);
        given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(quiz.getId()));
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1)).willReturn(List.of());

        AnswerSubmitResponse response =
                quizService.submitAnswer(USER_ID, 30L, new AnswerSubmitRequest(List.of("LIFO", "여분")));

        assertThat(response.isCorrect()).isFalse();
    }

    @Test
    @DisplayName("키워드 빈칸은 같은 빈칸에 등록된 동의어 중 하나만 맞아도 정답으로 처리한다")
    void grades_keyword_blank_correct_when_matching_any_synonym() {
        quizService = service();
        Quiz quiz = QuizFixture.keywordBlankQuiz(); // 기존 정답: slotOrder=1, "LIFO"
        quiz.addAnswerKeyword(1, "Last In First Out"); // 같은 슬롯에 동의어 추가
        quiz.assignPosition(1, 1);
        ReflectionTestUtils.setField(quiz, "id", 30L);
        given(quizRepository.findById(30L)).willReturn(Optional.of(quiz));
        stubSubmittableStep(1);
        given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(quiz.getId()));
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1)).willReturn(List.of());

        AnswerSubmitResponse response =
                quizService.submitAnswer(USER_ID, 30L, new AnswerSubmitRequest(List.of("Last In First Out")));

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
        stubSubmittableStep(1);
        given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(quiz.getId()));
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1)).willReturn(List.of());

        AnswerSubmitResponse response =
                quizService.submitAnswer(USER_ID, 20L, new AnswerSubmitRequest(List.of("garbage")));

        assertThat(response.isCorrect()).isFalse();
    }

    @Test
    @DisplayName("스텝의 모든 문제를 한 번씩 시도했으면 다음 스텝으로 진행한다")
    void advances_progress_when_step_fully_attempted() {
        quizService = service();
        Quiz last = quizWithId(10L, 1, 5);
        List<Quiz> stepQuizzes =
                List.of(quizWithId(6L, 1, 1), quizWithId(7L, 1, 2), quizWithId(8L, 1, 3), quizWithId(9L, 1, 4), last);
        given(quizRepository.findById(10L)).willReturn(Optional.of(last));
        stubSubmittableStep(1);
        given(quizRepository.findIdsByStepOrder(1))
                .willReturn(stepQuizzes.stream().map(Quiz::getId).toList());
        List<QuizAttempt> allAttempted = stepQuizzes.stream()
                .map(q -> QuizAttempt.create(q, USER_ID, true))
                .toList();
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1)).willReturn(allAttempted);

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
        List<Quiz> stepQuizzes =
                List.of(quizWithId(6L, 1, 1), quizWithId(7L, 1, 2), quizWithId(8L, 1, 3), quizWithId(9L, 1, 4), last);
        given(quizRepository.findById(10L)).willReturn(Optional.of(last));
        given(quizStepRepository.findByStepOrder(1)).willReturn(Optional.of(stepFixture(1, COURSE_ID)));
        given(quizStepRepository.findMinStepOrderByCourseId(COURSE_ID)).willReturn(Optional.of(1));
        given(quizRepository.findIdsByStepOrder(1))
                .willReturn(stepQuizzes.stream().map(Quiz::getId).toList());
        List<QuizAttempt> allAttempted = stepQuizzes.stream()
                .map(q -> QuizAttempt.create(q, USER_ID, true))
                .toList();
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1)).willReturn(allAttempted);
        given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                .willReturn(Optional.empty());
        given(quizProgressRepository.findByUserIdAndCourseIdForUpdate(USER_ID, COURSE_ID))
                .willReturn(Optional.empty());
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
        stubSubmittableStep(1);
        given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(10L, 11L));
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1)).willReturn(List.of());

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
                .satisfies(ex ->
                        assertThat(((BusinessException) ex).getErrorType()).isEqualTo(QuizErrorType.QUIZ_NOT_FOUND));
    }

    @Test
    @DisplayName("아직 진행하지 않은 미래 스텝의 문제는 QUIZ_NOT_ACCESSIBLE")
    void throws_quiz_not_accessible_when_step_is_ahead_of_progress() {
        quizService = service();
        Quiz futureQuiz = quizWithId(10L, 2, 1);
        given(quizRepository.findById(10L)).willReturn(Optional.of(futureQuiz));
        given(quizStepRepository.findByStepOrder(2)).willReturn(Optional.of(stepFixture(2, COURSE_ID)));
        given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                .willReturn(Optional.of(QuizProgress.create(USER_ID, COURSE_ID, 1)));
        assertThatThrownBy(() -> quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O"))))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex -> assertThat(((BusinessException) ex).getErrorType())
                        .isEqualTo(QuizErrorType.QUIZ_NOT_ACCESSIBLE));
    }

    @Test
    @DisplayName("이미 지난 스텝의 문제는 복습을 위해 제출할 수 있다")
    void allows_submitting_for_a_past_step() {
        quizService = service();
        QuizProgress progress = QuizProgress.create(USER_ID, COURSE_ID, 1);
        progress.advanceToNextStep(); // currentStepOrder=2
        Quiz pastQuiz = quizWithId(10L, 1, 1);
        given(quizRepository.findById(10L)).willReturn(Optional.of(pastQuiz));
        given(quizStepRepository.findByStepOrder(1)).willReturn(Optional.of(stepFixture(1, COURSE_ID)));
        given(quizProgressRepository.findByUserIdAndCourseId(USER_ID, COURSE_ID))
                .willReturn(Optional.of(progress));
        given(quizProgressRepository.findByUserIdAndCourseIdForUpdate(USER_ID, COURSE_ID))
                .willReturn(Optional.of(progress));
        given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(pastQuiz.getId()));
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1)).willReturn(List.of());
        AnswerSubmitResponse response = quizService.submitAnswer(USER_ID, 10L, new AnswerSubmitRequest(List.of("O")));

        assertThat(response.isCorrect()).isTrue();
    }
}
