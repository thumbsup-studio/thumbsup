package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Pageable;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.exception.CommonErrorType;
import studio.thumbsup.server.common.response.CursorCodec;
import studio.thumbsup.server.common.response.CursorPage;
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.dto.QuizAttemptHistoryResponse;
import studio.thumbsup.server.quiz.dto.QuizAttemptHistoryResponse.QuizAttemptHistoryItem;

/** {@link QuizServiceTest}에서 분리 — "풀이 기록 조회"(#261) 관련 테스트만 모았다. */
@ExtendWith(MockitoExtension.class)
@DisplayName("풀이 기록 조회")
class QuizAttemptHistoryServiceTest {

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
    private static final Instant NOW = Instant.parse("2026-07-11T00:00:00Z");
    private static final Instant ATTEMPT_CREATED_AT = Instant.parse("2026-07-07T00:00:00Z");

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

    private static Quiz oxQuizWithId(Long id) {
        Quiz quiz = QuizFixture.oxQuiz();
        quiz.assignPosition(1, 1);
        ReflectionTestUtils.setField(quiz, "id", id);
        return quiz;
    }

    private static Quiz multipleChoiceQuizWithId(Long id) {
        Quiz quiz = QuizFixture.multipleChoiceQuiz();
        quiz.assignPosition(1, 3);
        ReflectionTestUtils.setField(quiz, "id", id);
        long choiceId = 100L;
        for (QuizChoice choice : quiz.getChoices()) {
            ReflectionTestUtils.setField(choice, "id", choiceId++);
        }
        return quiz;
    }

    private static Quiz keywordBlankQuizWithId(Long id) {
        Quiz quiz = QuizFixture.keywordBlankQuiz();
        quiz.assignPosition(1, 5);
        ReflectionTestUtils.setField(quiz, "id", id);
        return quiz;
    }

    private static QuizAttempt attemptFixture(Long attemptId, Quiz quiz, boolean isCorrect, String selectedAnswer) {
        QuizAttempt attempt = QuizAttempt.create(quiz, USER_ID, isCorrect, selectedAnswer);
        ReflectionTestUtils.setField(attempt, "id", attemptId);
        ReflectionTestUtils.setField(attempt, "createdAt", ATTEMPT_CREATED_AT);
        return attempt;
    }

    private QuizAttemptHistoryItem firstItem(String cursor, int size) {
        return quizService
                .getAttemptHistory(USER_ID, cursor, size)
                .data()
                .items()
                .get(0);
    }

    @Nested
    @DisplayName("페이지네이션")
    class Pagination {

        @Test
        @DisplayName("size보다 1개 더 조회해 hasNext를 판별한다")
        void fetches_one_extra_row_to_detect_has_next() {
            quizService = service();
            Quiz quiz = oxQuizWithId(1L);
            given(quizAttemptRepository.findPageByUserId(eq(USER_ID), any(Pageable.class)))
                    .willReturn(List.of(
                            attemptFixture(3L, quiz, true, "O"),
                            attemptFixture(2L, quiz, false, "X"),
                            attemptFixture(1L, quiz, true, "O")));

            CursorPage<QuizAttemptHistoryResponse> page = quizService.getAttemptHistory(USER_ID, null, 2);

            ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
            verify(quizAttemptRepository).findPageByUserId(eq(USER_ID), pageable.capture());
            assertThat(pageable.getValue().getPageSize()).isEqualTo(3); // size + 1
            assertThat(page.data().items()).hasSize(2);
            assertThat(page.meta().hasNext()).isTrue();
            assertThat(page.meta().nextCursor()).isEqualTo(CursorCodec.encodeId(2L));
        }

        @Test
        @DisplayName("정확히 size개면 hasNext는 false다")
        void has_next_is_false_when_exactly_size() {
            quizService = service();
            Quiz quiz = oxQuizWithId(1L);
            given(quizAttemptRepository.findPageByUserId(eq(USER_ID), any(Pageable.class)))
                    .willReturn(List.of(attemptFixture(2L, quiz, true, "O"), attemptFixture(1L, quiz, true, "O")));

            CursorPage<QuizAttemptHistoryResponse> page = quizService.getAttemptHistory(USER_ID, null, 2);

            assertThat(page.data().items()).hasSize(2);
            assertThat(page.meta().hasNext()).isFalse();
            assertThat(page.meta().nextCursor()).isNull();
        }

        @Test
        @DisplayName("빈 결과는 hasNext false, nextCursor null")
        void empty_result_has_no_next_and_null_cursor() {
            quizService = service();
            given(quizAttemptRepository.findPageByUserId(eq(USER_ID), any(Pageable.class)))
                    .willReturn(List.of());

            CursorPage<QuizAttemptHistoryResponse> page = quizService.getAttemptHistory(USER_ID, null, 2);

            assertThat(page.data().items()).isEmpty();
            assertThat(page.meta().hasNext()).isFalse();
            assertThat(page.meta().nextCursor()).isNull();
        }

        @Test
        @DisplayName("커서가 있으면 디코딩한 id 미만을 이어서 조회한다")
        void decodes_cursor_and_fetches_below_it() {
            quizService = service();
            Quiz quiz = oxQuizWithId(1L);
            given(quizAttemptRepository.findPageByUserIdBeforeId(eq(USER_ID), eq(10L), any(Pageable.class)))
                    .willReturn(List.of(attemptFixture(9L, quiz, true, "O")));

            quizService.getAttemptHistory(USER_ID, CursorCodec.encodeId(10L), 2);

            verify(quizAttemptRepository).findPageByUserIdBeforeId(eq(USER_ID), eq(10L), any(Pageable.class));
        }

        @Test
        @DisplayName("디코딩 불가능한 커서는 INVALID_INPUT")
        void rejects_undecodable_cursor_with_invalid_input() {
            quizService = service();
            assertThatThrownBy(() -> quizService.getAttemptHistory(USER_ID, "!!not-base64!!", 2))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(e -> assertThat(((BusinessException) e).getErrorType())
                            .isEqualTo(CommonErrorType.INVALID_INPUT));
        }
    }

    @Nested
    @DisplayName("항목 매핑")
    class ItemMapping {

        @Test
        @DisplayName("문제 내용·정오·풀이 일시를 포함한다")
        void item_includes_question_and_result_fields() {
            quizService = service();
            Quiz quiz = oxQuizWithId(1L);
            given(quizAttemptRepository.findPageByUserId(eq(USER_ID), any(Pageable.class)))
                    .willReturn(List.of(attemptFixture(5L, quiz, true, "O")));

            QuizAttemptHistoryItem item = firstItem(null, 20);

            assertThat(item.attemptId()).isEqualTo(5L);
            assertThat(item.quizId()).isEqualTo(1L);
            assertThat(item.type()).isEqualTo(QuizType.OX);
            assertThat(item.questionText()).isEqualTo(quiz.getQuestionText());
            assertThat(item.isCorrect()).isTrue();
            assertThat(item.submittedAt()).isEqualTo(OffsetDateTime.of(2026, 7, 7, 9, 0, 0, 0, ZoneOffset.ofHours(9)));
        }
    }

    @Nested
    @DisplayName("선택한 답 표시")
    class SelectedAnswerDisplay {

        @Test
        @DisplayName("OX는 저장된 값을 그대로 보여준다")
        void ox_shows_raw_value() {
            quizService = service();
            Quiz quiz = oxQuizWithId(1L);
            given(quizAttemptRepository.findPageByUserId(eq(USER_ID), any(Pageable.class)))
                    .willReturn(List.of(attemptFixture(1L, quiz, true, "O")));

            assertThat(firstItem(null, 20).selectedAnswer()).isEqualTo("O");
        }

        @Test
        @DisplayName("사지선다는 저장된 choiceId를 선택지 문구로 치환한다")
        void multiple_choice_resolves_choice_content() {
            quizService = service();
            Quiz quiz = multipleChoiceQuizWithId(2L);
            QuizChoice correctChoice = quiz.getChoices().stream()
                    .filter(QuizChoice::isCorrect)
                    .findFirst()
                    .orElseThrow();
            given(quizAttemptRepository.findPageByUserId(eq(USER_ID), any(Pageable.class)))
                    .willReturn(List.of(attemptFixture(1L, quiz, true, String.valueOf(correctChoice.getId()))));

            assertThat(firstItem(null, 20).selectedAnswer()).isEqualTo(correctChoice.getContent());
        }

        @Test
        @DisplayName("사지선다는 선택지를 찾을 수 없으면 null로 표시한다")
        void multiple_choice_shows_null_when_choice_missing() {
            quizService = service();
            Quiz quiz = multipleChoiceQuizWithId(2L);
            given(quizAttemptRepository.findPageByUserId(eq(USER_ID), any(Pageable.class)))
                    .willReturn(List.of(attemptFixture(1L, quiz, false, "999999")));

            assertThat(firstItem(null, 20).selectedAnswer()).isNull();
        }

        @Test
        @DisplayName("빈칸은 쉼표로 저장된 값을 보기 좋게 다시 잇는다")
        void keyword_blank_rejoins_stored_answers() {
            quizService = service();
            Quiz quiz = keywordBlankQuizWithId(3L);
            given(quizAttemptRepository.findPageByUserId(eq(USER_ID), any(Pageable.class)))
                    .willReturn(List.of(attemptFixture(1L, quiz, true, "LIFO,스택")));

            assertThat(firstItem(null, 20).selectedAnswer()).isEqualTo("LIFO, 스택");
        }

        @Test
        @DisplayName("이 필드 도입 이전 기록(selectedAnswer 없음)은 null로 내려간다")
        void legacy_attempt_without_selected_answer_shows_null() {
            quizService = service();
            Quiz quiz = oxQuizWithId(1L);
            given(quizAttemptRepository.findPageByUserId(eq(USER_ID), any(Pageable.class)))
                    .willReturn(List.of(attemptFixture(1L, quiz, true, null)));

            assertThat(firstItem(null, 20).selectedAnswer()).isNull();
        }
    }
}
