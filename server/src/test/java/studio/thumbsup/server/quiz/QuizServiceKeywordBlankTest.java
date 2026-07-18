package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.quiz.dto.AnswerSubmitRequest;
import studio.thumbsup.server.quiz.dto.AnswerSubmitResponse;

/**
 * 키워드 빈칸 문제의 정답 매칭 규칙을 검증한다 — 슬롯 개수, 동의어, 그리고 대소문자·띄어쓰기 표기 차이 허용.
 * 같은 서비스를 다루지만 {@code QuizServiceTest}에서 분리했다(checkstyle 파일 길이 상한 400줄).
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("키워드 빈칸 채점")
class QuizServiceKeywordBlankTest {

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
    }

    private AnswerSubmitResponse submit(String... answers) {
        return service().submitAnswer(USER_ID, QUIZ_ID, new AnswerSubmitRequest(List.of(answers)));
    }

    @Test
    @DisplayName("슬롯 순서대로 대소문자·앞뒤 공백을 무시하고 비교한다")
    void grades_ignoring_case_and_surrounding_whitespace() {
        givenOnlyQuizInStep(QuizFixture.keywordBlankQuiz()); // answerKeywords = ["LIFO"]

        assertThat(submit("  lifo  ").isCorrect()).isTrue();
    }

    @Test
    @DisplayName("제출 개수가 정답 개수와 다르면 오답으로 처리한다")
    void grades_incorrect_when_answer_count_mismatches() {
        givenOnlyQuizInStep(QuizFixture.keywordBlankQuiz()); // answerKeywords = ["LIFO"] (1개)

        assertThat(submit("LIFO", "여분").isCorrect()).isFalse();
    }

    @Test
    @DisplayName("같은 빈칸에 등록된 동의어 중 하나만 맞아도 정답으로 처리한다")
    void grades_correct_when_matching_any_synonym() {
        Quiz quiz = QuizFixture.keywordBlankQuiz(); // 기존 정답: slotOrder=1, "LIFO"
        quiz.addAnswerKeyword(1, "Last In First Out"); // 같은 슬롯에 동의어 추가
        givenOnlyQuizInStep(quiz);

        assertThat(submit("Last In First Out").isCorrect()).isTrue();
    }

    @Test
    @DisplayName("정답에 있는 단어 사이 띄어쓰기를 생략해도 정답으로 처리한다")
    void grades_correct_when_internal_whitespace_is_omitted() {
        Quiz quiz = QuizFixture.keywordBlankQuiz();
        quiz.addAnswerKeyword(1, "Last In First Out"); // 띄어쓰기가 들어간 동의어
        givenOnlyQuizInStep(quiz);

        assertThat(submit("lastinfirstout").isCorrect()).isTrue();
    }

    @Test
    @DisplayName("정답에 없는 띄어쓰기를 넣어 제출해도 정답으로 처리한다")
    void grades_correct_when_internal_whitespace_is_added() {
        givenOnlyQuizInStep(QuizFixture.keywordBlankQuiz()); // 정답: "LIFO" (띄어쓰기 없음)

        assertThat(submit("L I F O").isCorrect()).isTrue();
    }

    @Test
    @DisplayName("띄어쓰기를 무시해도 글자가 다르면 오답으로 처리한다")
    void grades_incorrect_when_characters_differ() {
        givenOnlyQuizInStep(QuizFixture.keywordBlankQuiz()); // 정답: "LIFO"

        assertThat(submit("F I F O").isCorrect()).isFalse();
    }
}
