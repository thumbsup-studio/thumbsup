package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.BDDMockito.given;

import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.dto.QuizExplanationResponse;

/**
 * 해설 조회(#43)의 응답 조립 규칙을 검증한다 — 어떤 필드가 어떤 순서로 담기는가.
 * 같은 서비스를 다루지만 {@code QuizServiceTest}에서 분리했다(checkstyle 파일 길이 상한 400줄).
 *
 * <p>마커 파싱 자체의 분기는 {@link ExplanationTextParserTest}가 전수 검증하므로 여기서 반복하지 않는다.
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("해설 조회")
class QuizExplanationServiceTest {

    private static final Long QUIZ_ID = 10L;
    private static final Long ABSENT_QUIZ_ID = 999L;

    @Mock
    private QuizRepository quizRepository;

    @Mock
    private QuizAttemptRepository quizAttemptRepository;

    @Mock
    private QuizProgressRepository quizProgressRepository;

    private QuizService service() {
        return new QuizService(quizRepository, quizAttemptRepository, quizProgressRepository);
    }

    private static Quiz annotatedQuizWithId(Long id) {
        Quiz quiz = QuizFixture.annotatedExplanationQuiz();
        ReflectionTestUtils.setField(quiz, "id", id);
        return quiz;
    }

    private static Quiz plainQuizWithId(Long id) {
        Quiz quiz = QuizFixture.oxQuiz();
        ReflectionTestUtils.setField(quiz, "id", id);
        return quiz;
    }

    @Test
    @DisplayName("마커를 제거한 본문과 하이라이트 구간을 함께 반환한다")
    void returns_summary_with_highlights() {
        given(quizRepository.findById(QUIZ_ID)).willReturn(Optional.of(annotatedQuizWithId(QUIZ_ID)));

        QuizExplanationResponse response = service().getExplanation(QUIZ_ID);

        assertThat(response.quizId()).isEqualTo(QUIZ_ID);
        assertThat(response.explanationSummary()).hasSize(2);

        QuizExplanationResponse.AnnotatedText firstLine =
                response.explanationSummary().get(0);
        assertThat(firstLine.text()).isEqualTo("TCP는 연결 지향 프로토콜이다.");
        assertThat(firstLine.highlights()).containsExactly(new QuizExplanationResponse.Highlight("연결 지향", 5, 10));
    }

    @Test
    @DisplayName("해설 본문에 없는 키워드도 오답 해설에서 하이라이트된다")
    void highlights_keyword_found_only_in_wrong_answer_explanation() {
        given(quizRepository.findById(QUIZ_ID)).willReturn(Optional.of(annotatedQuizWithId(QUIZ_ID)));

        QuizExplanationResponse response = service().getExplanation(QUIZ_ID);

        assertThat(response.wrongAnswerExplanation().text()).isEqualTo("UDP는 비연결형이라 handshake가 없다.");
        assertThat(response.wrongAnswerExplanation().highlights())
                .extracting(QuizExplanationResponse.Highlight::keyword)
                .containsExactly("비연결형");
    }

    @Test
    @DisplayName("대표 꼬리질문을 저작 순서와 무관하게 맨 앞에 둔다")
    void puts_primary_follow_up_question_first() {
        given(quizRepository.findById(QUIZ_ID)).willReturn(Optional.of(annotatedQuizWithId(QUIZ_ID)));

        QuizExplanationResponse response = service().getExplanation(QUIZ_ID);

        assertThat(response.followUpQuestions()).containsExactly("대표 질문입니다.", "보조 질문입니다.");
    }

    @Test
    @DisplayName("예시가 없으면 null이고, 마커가 없는 본문은 하이라이트 없이 내려간다")
    void returns_null_example_and_no_highlights_without_markers() {
        given(quizRepository.findById(QUIZ_ID)).willReturn(Optional.of(plainQuizWithId(QUIZ_ID)));

        QuizExplanationResponse response = service().getExplanation(QUIZ_ID);

        assertThat(response.explanationExample()).isNull();
        assertThat(response.explanationSummary()).hasSize(1);
        assertThat(response.explanationSummary().get(0).highlights()).isEmpty();
    }

    @Test
    @DisplayName("존재하지 않는 문제면 QUIZ_NOT_FOUND")
    void throws_quiz_not_found_when_absent() {
        given(quizRepository.findById(ABSENT_QUIZ_ID)).willReturn(Optional.empty());

        QuizService quizService = service();
        assertThatThrownBy(() -> quizService.getExplanation(ABSENT_QUIZ_ID))
                .isInstanceOf(BusinessException.class)
                .satisfies(ex ->
                        assertThat(((BusinessException) ex).getErrorType()).isEqualTo(QuizErrorType.QUIZ_NOT_FOUND));
    }
}
