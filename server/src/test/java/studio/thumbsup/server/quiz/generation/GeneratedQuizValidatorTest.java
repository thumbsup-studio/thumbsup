package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture.oxQuizJson;
import static studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture.setJsonWithFirstQuiz;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizType;

class GeneratedQuizValidatorTest {

    private final GeneratedQuizValidator validator = new GeneratedQuizValidator(new ObjectMapper());

    @Nested
    @DisplayName("parse")
    class Parse {

        @Test
        @DisplayName("마크다운 코드펜스로 감싸진 응답도 벗겨내 역직렬화한다")
        void strips_markdown_fence_before_deserializing() {
            String fenced = "```json\n" + setJsonWithFirstQuiz(oxQuizJson()) + "\n```";

            GeneratedQuizSet parsed = validator.parse(fenced);

            assertThat(parsed.quizzes()).hasSize(5);
        }

        @Test
        @DisplayName("엘리스 응답이 JSON이 아니면 파싱 실패 예외")
        void throws_when_response_is_not_json() {
            assertThatThrownBy(() -> validator.parse("이건 JSON이 아니에요"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("파싱하지 못했습니다");
        }
    }

    @Nested
    @DisplayName("validateSingle")
    class ValidateSingle {

        @Test
        @DisplayName("기대 type/difficulty와 다르면 예외")
        void throws_when_type_or_difficulty_mismatches() {
            GeneratedQuizSet.GeneratedQuiz quiz = validator
                    .parse(setJsonWithFirstQuiz(oxQuizJson()))
                    .quizzes()
                    .get(0);

            assertThatThrownBy(() -> validator.validateSingle(quiz, QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("유형/난이도가 예상과 다릅니다");
        }

        @Test
        @DisplayName("정상 단건은 예외 없이 통과한다")
        void passes_for_valid_single_quiz() {
            GeneratedQuizSet.GeneratedQuiz quiz = validator
                    .parse(setJsonWithFirstQuiz(oxQuizJson()))
                    .quizzes()
                    .get(0);

            assertThatCode(() -> validator.validateSingle(quiz, QuizType.OX, QuizDifficulty.EASY))
                    .doesNotThrowAnyException();
        }
    }
}
