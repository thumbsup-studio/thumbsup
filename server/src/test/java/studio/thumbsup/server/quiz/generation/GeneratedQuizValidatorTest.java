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
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
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
        @DisplayName("생성 응답이 JSON이 아니면 파싱 실패 예외")
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

    @Nested
    @DisplayName("한 문장 힌트 검증")
    class ValidateHint {

        @Test
        @DisplayName("개행으로 두 문장을 작성하면 거부한다")
        void rejects_multiple_lines() {
            String json = oxQuizJson().replace("핵심 개념이 맡는 역할과 적용 조건을 떠올려 보세요.", "첫 번째 단서입니다.\\n두 번째 단서입니다.");
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse(setJsonWithFirstQuiz(json)).quizzes().get(0);

            assertThatThrownBy(() -> validator.validateSingle(quiz, QuizType.OX, QuizDifficulty.EASY))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("개행 없는 한 문장");
        }

        @Test
        @DisplayName("같은 줄에 실제 문장이 둘이면 거부한다")
        void rejects_two_sentences_on_one_line() {
            String json = oxQuizJson().replace("핵심 개념이 맡는 역할과 적용 조건을 떠올려 보세요.", "첫 번째 단서입니다. 두 번째 조건을 떠올려 보세요.");
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse(setJsonWithFirstQuiz(json)).quizzes().get(0);

            assertThatThrownBy(() -> validator.validateSingle(quiz, QuizType.OX, QuizDifficulty.EASY))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("개행 없는 한 문장");
        }

        @Test
        @DisplayName("200자를 넘고 복수 문장인 hint는 문장 정규식보다 길이를 먼저 거부한다")
        void rejects_overlong_hint_before_sentence_pattern() {
            String overlongHint = "가".repeat(201) + ". 두 번째 문장입니다.";
            String json = oxQuizJson().replace("핵심 개념이 맡는 역할과 적용 조건을 떠올려 보세요.", overlongHint);
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse(setJsonWithFirstQuiz(json)).quizzes().get(0);

            assertThatThrownBy(() -> validator.validateSingle(quiz, QuizType.OX, QuizDifficulty.EASY))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("200자를 초과");
        }

        @ParameterizedTest(name = "{0}")
        @ValueSource(strings = {"\\n핵심 개념을 떠올려 보세요.", "핵심 개념을 떠올려 보세요.\\n"})
        @DisplayName("문장 앞뒤 개행도 trim으로 숨기지 않고 거부한다")
        void rejects_leading_or_trailing_newline(String hintWithNewline) {
            String json = oxQuizJson().replace("핵심 개념이 맡는 역할과 적용 조건을 떠올려 보세요.", hintWithNewline);
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse(setJsonWithFirstQuiz(json)).quizzes().get(0);

            assertThatThrownBy(() -> validator.validateSingle(quiz, QuizType.OX, QuizDifficulty.EASY))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("개행 없는 한 문장");
        }

        @ParameterizedTest(name = "{0}")
        @ValueSource(
                strings = {
                    "분모가 0이 아닐 때만 성립합니다.",
                    "이 병목은 I/O입니다.",
                    "1.5초를 기준으로 비교하세요.",
                    "e.g. 처리량과 지연 시간의 관계를 비교해 보세요.",
                    "System.out을 기준으로 흐름을 추적하세요.",
                    "O와 X 표기의 의미를 비교해 보세요.",
                    "서버 응답이 늦어지는 조건을 떠올려 보세요.",
                    "오답이 생기는 경계 조건을 비교해 보세요.",
                    "BOX 모델이 구분하는 영역을 떠올려 보세요."
                })
        @DisplayName("약어·조건 설명·답/OX 부분 문자열은 결론이나 복수 문장으로 오탐하지 않는다")
        void allows_safe_conditional_io_and_decimal_hints(String safeHint) {
            String json = oxQuizJson().replace("핵심 개념이 맡는 역할과 적용 조건을 떠올려 보세요.", safeHint);
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse(setJsonWithFirstQuiz(json)).quizzes().get(0);

            assertThatCode(() -> validator.validateSingle(quiz, QuizType.OX, QuizDifficulty.EASY))
                    .doesNotThrowAnyException();
        }

        @Test
        @DisplayName("OX 힌트가 참·거짓 판단 결론을 말하면 거부한다")
        void rejects_ox_verdict() {
            String json = oxQuizJson().replace("핵심 개념이 맡는 역할과 적용 조건을 떠올려 보세요.", "이 설명은 참입니다.");
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse(setJsonWithFirstQuiz(json)).quizzes().get(0);

            assertThatThrownBy(() -> validator.validateSingle(quiz, QuizType.OX, QuizDifficulty.EASY))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("판단 결론");
        }

        @ParameterizedTest(name = "{0}")
        @ValueSource(strings = {"답이 O입니다.", "정답이다: O입니다."})
        @DisplayName("답이·정답이다 형태로 실제 정답을 지시하면 거부한다")
        void rejects_direct_answer_variants(String leakingHint) {
            String json = oxQuizJson().replace("핵심 개념이 맡는 역할과 적용 조건을 떠올려 보세요.", leakingHint);
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse(setJsonWithFirstQuiz(json)).quizzes().get(0);

            assertThatThrownBy(() -> validator.validateSingle(quiz, QuizType.OX, QuizDifficulty.EASY))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("정답을 직접 지시");
        }

        @ParameterizedTest(name = "{0}")
        @ValueSource(
                strings = {
                    "O를 선택하세요.",
                    "O가 맞아요.",
                    "X는 틀렸습니다.",
                    "참을 선택하세요.",
                    "거짓을 고르세요.",
                    "거짓으로 판단하세요.",
                    "이 명제는 사실입니다.",
                    "이 설명은 성립합니다.",
                    "이 문장은 올바릅니다."
                })
        @DisplayName("OX 힌트가 라벨이나 판단 지시로 결론을 말해도 거부한다")
        void rejects_ox_label_and_directed_verdict(String leakingHint) {
            String json = oxQuizJson().replace("핵심 개념이 맡는 역할과 적용 조건을 떠올려 보세요.", leakingHint);
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse(setJsonWithFirstQuiz(json)).quizzes().get(0);

            assertThatThrownBy(() -> validator.validateSingle(quiz, QuizType.OX, QuizDifficulty.EASY))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("판단 결론");
        }

        @Test
        @DisplayName("사지선다 힌트가 선택지 라벨을 말하면 거부한다")
        void rejects_multiple_choice_label() {
            String json = GeneratedQuizJsonFixture.multipleChoiceQuizJson()
                    .replace("핵심 개념이 맡는 역할과 적용 조건을 떠올려 보세요.", "2번 선택지를 확인해 보세요.");
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse("{\"quizzes\":[" + json + "]}").quizzes().get(0);

            assertThatThrownBy(() -> validator.validateSingle(quiz, QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("선택지 라벨");
        }

        @ParameterizedTest(name = "{0}")
        @ValueSource(strings = {"각 선택지가 요구하는 조건을 비교해 보세요.", "각 선택지나 개념의 조건을 비교해 보세요."})
        @DisplayName("선택지 뒤의 자연스러운 한국어 조사는 선택지 라벨로 오탐하지 않는다")
        void allows_korean_particle_after_choice_word(String safeHint) {
            String json = GeneratedQuizJsonFixture.multipleChoiceQuizJson()
                    .replace("핵심 개념이 맡는 역할과 적용 조건을 떠올려 보세요.", safeHint);
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse("{\"quizzes\":[" + json + "]}").quizzes().get(0);

            assertThatCode(() -> validator.validateSingle(quiz, QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM))
                    .doesNotThrowAnyException();
        }

        @ParameterizedTest(name = "{0}")
        @ValueSource(
                strings = {"B 선택지를 골라 보세요.", "보기 ③을 확인해 보세요.", "(B) 선택지를 골라 보세요.", "보기B를 확인해 보세요.", "보기 가를 확인해 보세요."})
        @DisplayName("사지선다 힌트의 문자·원문자 라벨 변형도 거부한다")
        void rejects_multiple_choice_label_variants(String leakingHint) {
            String json = GeneratedQuizJsonFixture.multipleChoiceQuizJson()
                    .replace("핵심 개념이 맡는 역할과 적용 조건을 떠올려 보세요.", leakingHint);
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse("{\"quizzes\":[" + json + "]}").quizzes().get(0);

            assertThatThrownBy(() -> validator.validateSingle(quiz, QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("선택지 라벨");
        }

        @ParameterizedTest(name = "{0}")
        @ValueSource(strings = {"B가 맞아요.", "(C)는 정답입니다."})
        @DisplayName("사지선다 힌트가 독립 라벨 뒤에 판정 결론을 말하면 거부한다")
        void rejects_multiple_choice_label_verdict(String leakingHint) {
            String json = GeneratedQuizJsonFixture.multipleChoiceQuizJson()
                    .replace(
                            "{\"content\": \"b\", \"isCorrect\": true}",
                            "{\"content\": \"정답 내용\", \"isCorrect\": true}")
                    .replace("핵심 개념이 맡는 역할과 적용 조건을 떠올려 보세요.", leakingHint);
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse("{\"quizzes\":[" + json + "]}").quizzes().get(0);

            assertThatThrownBy(() -> validator.validateSingle(quiz, QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("선택지 라벨");
        }

        @Test
        @DisplayName("사지선다 라벨과 같은 표기가 개념 이름의 맥락에 있으면 허용한다")
        void allows_contextual_option_label_mention() {
            String json = GeneratedQuizJsonFixture.multipleChoiceQuizJson()
                    .replace("핵심 개념이 맡는 역할과 적용 조건을 떠올려 보세요.", "(C) 언어의 메모리 모델을 떠올려 보세요.");
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse("{\"quizzes\":[" + json + "]}").quizzes().get(0);

            assertThatCode(() -> validator.validateSingle(quiz, QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM))
                    .doesNotThrowAnyException();
        }

        @Test
        @DisplayName("사지선다 힌트가 정답 선택지 문구를 그대로 말하면 거부한다")
        void rejects_correct_choice_content() {
            String json = GeneratedQuizJsonFixture.multipleChoiceQuizJson()
                    .replace("핵심 개념이 맡는 역할과 적용 조건을 떠올려 보세요.", "b를 기준으로 판단해 보세요.");
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse("{\"quizzes\":[" + json + "]}").quizzes().get(0);

            assertThatThrownBy(() -> validator.validateSingle(quiz, QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("정답 선택지");
        }

        @Test
        @DisplayName("정답 선택지 content가 null이어도 NPE 대신 생성 검증 오류로 거부한다")
        void rejects_null_correct_choice_content() {
            String json = GeneratedQuizJsonFixture.multipleChoiceQuizJson()
                    .replace("{\"content\": \"b\", \"isCorrect\": true}", "{\"content\": null, \"isCorrect\": true}");
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse("{\"quizzes\":[" + json + "]}").quizzes().get(0);

            assertThatThrownBy(() -> validator.validateSingle(quiz, QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("choices[2].content");
        }

        @Test
        @DisplayName("빈칸 힌트가 정답의 공백·대소문자 변형을 포함하면 거부한다")
        void rejects_blank_answer_synonym() {
            String json = GeneratedQuizJsonFixture.keywordBlankQuizJson()
                    .replace("핵심 개념이 맡는 역할과 적용 조건을 떠올려 보세요.", "last in first out의 순서를 떠올려 보세요.");
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse("{\"quizzes\":[" + json + "]}").quizzes().get(0);

            assertThatThrownBy(() -> validator.validateSingle(quiz, QuizType.KEYWORD_BLANK, QuizDifficulty.HARD))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("정답 키워드");
        }

        @Test
        @DisplayName("빈칸 정답 동의어가 null이어도 NPE 대신 생성 검증 오류로 거부한다")
        void rejects_null_blank_answer_synonym() {
            String json = GeneratedQuizJsonFixture.keywordBlankQuizJson()
                    .replace("[[\"LIFO\", \"Last In First Out\"]]", "[[null, \"Last In First Out\"]]");
            GeneratedQuizSet.GeneratedQuiz quiz =
                    validator.parse("{\"quizzes\":[" + json + "]}").quizzes().get(0);

            assertThatThrownBy(() -> validator.validateSingle(quiz, QuizType.KEYWORD_BLANK, QuizDifficulty.HARD))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("answerKeywords[1][1]");
        }
    }
}
