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
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.quiz.dto.AnswerSubmitRequest;
import studio.thumbsup.server.quiz.dto.AnswerSubmitResponse;
import studio.thumbsup.server.quiz.dto.RetryHint;

/**
 * 오답 재도전 힌트(#63)를 검증한다 — 중·상 난이도 오답일 때만 정답을 흘리지 않는 부분 힌트를 준다.
 * 사지선다는 오답 하나를 소거하고, 빈칸은 슬롯별 첫 글자·글자수를 준다. 정답·EASY·OX·키워드 미등록은 힌트가 없다.
 * 같은 서비스를 다루지만 {@code QuizServiceTest}에서 분리했다(checkstyle 파일 길이 상한 400줄).
 */
@ExtendWith(MockitoExtension.class)
class QuizServiceRetryHintTest {

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

    private static final Long USER_ID = 1L;
    private static final Long QUIZ_ID = 30L;
    private static final Instant NOW = Instant.parse("2026-07-11T00:00:00Z");

    /** 사지선다 선택지 id — displayOrder 1~4 순서대로. displayOrder 3(id 103)이 정답이다. */
    private static final long FIRST_CHOICE_ID = 101L;

    private static final long CORRECT_CHOICE_ID = 103L;

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

    /** 스텝의 유일한 문제로 배치하고, 아직 아무 문제도 풀지 않은 상태로 만든다. */
    private void givenOnlyQuizInStep(Quiz quiz) {
        quiz.assignPosition(1, 1);
        ReflectionTestUtils.setField(quiz, "id", QUIZ_ID);
        given(quizRepository.findById(QUIZ_ID)).willReturn(Optional.of(quiz));
        given(quizRepository.findIdsByStepOrder(1)).willReturn(List.of(quiz.getId()));
        given(quizAttemptRepository.findByUserIdAndQuiz_StepOrder(USER_ID, 1)).willReturn(List.of());
        given(quizProgressRepository.findByUserIdForUpdate(USER_ID))
                .willReturn(Optional.of(QuizProgress.create(USER_ID)));
    }

    private RetryHint submit(String... answers) {
        AnswerSubmitResponse response =
                service().submitAnswer(USER_ID, QUIZ_ID, new AnswerSubmitRequest(List.of(answers)));
        return response.retryHint();
    }

    /** 사지선다 문제에 선택지 id를 displayOrder 순서대로 101~104로 부여한다. */
    private static Quiz multipleChoiceQuizWithChoiceIds() {
        Quiz quiz = QuizFixture.multipleChoiceQuiz();
        long choiceId = FIRST_CHOICE_ID;
        for (QuizChoice choice : quiz.getChoices()) {
            ReflectionTestUtils.setField(choice, "id", choiceId++);
        }
        return quiz;
    }

    /**
     * 삽입 순서와 displayOrder가 어긋난 사지선다 — 소거가 컬렉션 순회 순서가 아니라 displayOrder를 따르는지 검증용.
     * 삽입 순서상 첫 오답은 id 301(displayOrder 3)이지만, displayOrder상 첫 오답은 id 302(displayOrder 1)다.
     */
    private static Quiz multipleChoiceQuizWithShuffledDisplayOrder() {
        Quiz quiz = Quiz.create(QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM, "질문", null, "요약", "예시", "오답 해설");
        quiz.addChoice("가", false, 3);
        quiz.addChoice("나", false, 1);
        quiz.addChoice("다", true, 2);
        quiz.addChoice("라", false, 4);
        long choiceId = 301L;
        for (QuizChoice choice : quiz.getChoices()) {
            ReflectionTestUtils.setField(choice, "id", choiceId++);
        }
        return quiz;
    }

    /** 키워드가 아직 등록되지 않은 빈칸 문제 — 슬롯 키워드는 테스트에서 필요한 만큼 추가한다. */
    private static Quiz bareKeywordBlankQuiz() {
        return Quiz.create(
                QuizType.KEYWORD_BLANK,
                QuizDifficulty.HARD,
                "___은 응용 프로그램이 운영체제 커널 기능을 요청하는 인터페이스다.",
                null,
                "요약",
                null,
                "오답 해설");
    }

    @Nested
    @DisplayName("사지선다 오답 재도전 힌트")
    class MultipleChoiceHint {

        @Test
        @DisplayName("소거되는 선택지는 오답이고, 사용자가 방금 고른 선택지와 다르다")
        void eliminates_a_wrong_choice_other_than_the_users_pick() {
            givenOnlyQuizInStep(multipleChoiceQuizWithChoiceIds());

            // 첫 번째 오답(id 101)을 골라 틀린다 — 소거 로직이 이 선택지를 건너뛰어야 한다.
            RetryHint hint = submit(String.valueOf(FIRST_CHOICE_ID));

            Long eliminated = hint.eliminatedChoiceId();
            assertThat(eliminated).isNotEqualTo(CORRECT_CHOICE_ID); // 오답을 소거
            assertThat(eliminated).isNotEqualTo(FIRST_CHOICE_ID); // 사용자가 고른 것은 소거 대상이 아님
            assertThat(eliminated).isEqualTo(102L); // displayOrder 기준 그다음 오답(결정적)
            assertThat(hint.blankHints()).isNull();
        }

        @Test
        @DisplayName("파싱 불가한 선택지 id를 제출하면 오답 중 표시 순서상 첫 번째를 소거한다")
        void eliminates_first_wrong_choice_when_submission_is_unparseable() {
            givenOnlyQuizInStep(multipleChoiceQuizWithChoiceIds());

            RetryHint hint = submit("not-a-number");

            assertThat(hint.eliminatedChoiceId()).isEqualTo(FIRST_CHOICE_ID);
        }

        @Test
        @DisplayName("컬렉션 순회 순서가 아니라 displayOrder가 가장 앞선 오답을 소거한다")
        void eliminates_wrong_choice_by_display_order_not_collection_order() {
            givenOnlyQuizInStep(multipleChoiceQuizWithShuffledDisplayOrder());

            // 파싱 불가값 제출 → 사용자 선택 제외 없이 오답 중 displayOrder 첫 번째를 골라야 한다.
            RetryHint hint = submit("not-a-number");

            // 정렬이 없으면 삽입 순서상 첫 오답 301이 나온다 — displayOrder 정렬이면 302다.
            assertThat(hint.eliminatedChoiceId()).isEqualTo(302L);
        }
    }

    @Nested
    @DisplayName("빈칸 오답 재도전 힌트")
    class KeywordBlankHint {

        @Test
        @DisplayName("슬롯마다 첫 글자와 공백 제외 글자수를 주고, 슬롯이 2개면 힌트도 2개다")
        void reveals_prefix_and_length_per_slot() {
            Quiz quiz = bareKeywordBlankQuiz();
            quiz.addAnswerKeyword(1, "시스템 콜"); // 공백 제외 4글자
            quiz.addAnswerKeyword(2, "데드락"); // 3글자
            givenOnlyQuizInStep(quiz);

            RetryHint hint = submit("틀린답1", "틀린답2");

            assertThat(hint.eliminatedChoiceId()).isNull();
            assertThat(hint.blankHints())
                    .containsExactly(new RetryHint.BlankHint(1, "시", 4), new RetryHint.BlankHint(2, "데", 3));
        }

        @Test
        @DisplayName("정답 키워드가 등록되지 않은 문제는 힌트를 주지 않는다")
        void returns_null_when_no_answer_keyword_registered() {
            givenOnlyQuizInStep(bareKeywordBlankQuiz());

            assertThat(submit("아무답")).isNull();
        }
    }

    @Nested
    @DisplayName("힌트를 주지 않는 경우")
    class NoHint {

        @Test
        @DisplayName("정답이면 힌트가 없다")
        void returns_null_when_correct() {
            givenOnlyQuizInStep(multipleChoiceQuizWithChoiceIds());

            assertThat(submit(String.valueOf(CORRECT_CHOICE_ID))).isNull();
        }

        @Test
        @DisplayName("하 난이도(OX) 오답이면 힌트가 없다")
        void returns_null_when_easy_ox() {
            givenOnlyQuizInStep(QuizFixture.oxQuiz()); // 정답 "O"

            assertThat(submit("X")).isNull();
        }
    }
}
