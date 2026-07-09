package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.QuizType;

@ExtendWith(MockitoExtension.class)
class QuizGenerationServiceTest {

    @Mock
    private EliceClient eliceClient;

    @Mock
    private QuizRepository quizRepository;

    @Mock
    private QuizStepRepository quizStepRepository;

    private final ObjectMapper objectMapper = new ObjectMapper();

    private QuizGenerationService service() {
        return new QuizGenerationService(eliceClient, quizRepository, quizStepRepository, objectMapper);
    }

    private static String quizJson(String type, String difficulty, String extraFields) {
        return """
                {
                  "type": "%s",
                  "difficulty": "%s",
                  "questionText": "질문 본문",
                  "codeSnippet": null,
                  "explanationSummary": "[[PCB]]는 핵심 요약 1줄.\\n핵심 요약 2줄.\\n핵심 요약 3줄.",
                  "explanationExample": null,
                  "wrongAnswerExplanation": "오답 해설",
                  %s,
                  "followUpQuestions": [{"content": "꼬리질문", "isPrimary": true}],
                  "derivedConcepts": ["개념1"],
                  "keywords": [{"keyword": "PCB", "description": "설명"}]
                }
                """.formatted(type, difficulty, extraFields);
    }

    private static String oxQuizJson() {
        return quizJson("OX", "EASY", "\"correctAnswer\": \"O\", \"choices\": null, \"answerKeywords\": null");
    }

    private static String multipleChoiceQuizJson() {
        return quizJson("MULTIPLE_CHOICE", "MEDIUM", """
                "correctAnswer": null, "answerKeywords": null,
                "choices": [
                  {"content": "a", "isCorrect": false},
                  {"content": "b", "isCorrect": true},
                  {"content": "c", "isCorrect": false},
                  {"content": "d", "isCorrect": false}
                ]
                """);
    }

    private static String keywordBlankQuizJson() {
        return quizJson(
                "KEYWORD_BLANK",
                "HARD",
                "\"correctAnswer\": null, \"choices\": null, \"answerKeywords\": [[\"LIFO\", \"Last In First Out\"]]");
    }

    private static String validSetJson() {
        return "{\"quizzes\": [%s, %s, %s, %s, %s]}"
                .formatted(
                        oxQuizJson(),
                        oxQuizJson(),
                        multipleChoiceQuizJson(),
                        multipleChoiceQuizJson(),
                        keywordBlankQuizJson());
    }

    @Nested
    @DisplayName("정상 생성")
    class GenerateStep {

        @Test
        @DisplayName("유효한 응답이면 5문제를 스텝·슬롯 순서대로 저장한다")
        void saves_five_quizzes_in_slot_order() {
            given(quizRepository.findMaxStepOrder()).willReturn(Optional.of(3));
            given(eliceClient.generate(any())).willReturn(validSetJson());

            int stepOrder = service().generateStep("운영체제");

            assertThat(stepOrder).isEqualTo(4);
            ArgumentCaptor<Quiz> captor = ArgumentCaptor.forClass(Quiz.class);
            verify(quizRepository, times(5)).save(captor.capture());
            assertThat(captor.getAllValues()).extracting(Quiz::getSlotOrder).containsExactly(1, 2, 3, 4, 5);
            assertThat(captor.getAllValues())
                    .allSatisfy(quiz -> assertThat(quiz.getStepOrder()).isEqualTo(4));
        }

        @Test
        @DisplayName("스텝 주제(QuizStep)도 함께 저장한다")
        void saves_quiz_step_topic() {
            given(quizRepository.findMaxStepOrder()).willReturn(Optional.of(3));
            given(eliceClient.generate(any())).willReturn(validSetJson());

            service().generateStep("CPU 스케줄링 기초");

            ArgumentCaptor<QuizStep> captor = ArgumentCaptor.forClass(QuizStep.class);
            verify(quizStepRepository).save(captor.capture());
            assertThat(captor.getValue().getStepOrder()).isEqualTo(4);
            assertThat(captor.getValue().getTopic()).isEqualTo("CPU 스케줄링 기초");
        }

        @Test
        @DisplayName("기존 스텝이 없으면 1스텝부터 생성한다")
        void starts_from_step_one_when_no_existing_step() {
            given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
            given(eliceClient.generate(any())).willReturn(validSetJson());

            int stepOrder = service().generateStep("운영체제");

            assertThat(stepOrder).isEqualTo(1);
        }

        @Test
        @DisplayName("마크다운 코드펜스로 감싸진 응답도 파싱한다")
        void strips_markdown_fence_before_parsing() {
            given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
            given(eliceClient.generate(any())).willReturn("```json\n" + validSetJson() + "\n```");

            assertThat(service().generateStep("운영체제")).isEqualTo(1);
            verify(quizRepository, times(5)).save(any());
        }
    }

    @Nested
    @DisplayName("검증 실패")
    class ValidationFailure {

        @Test
        @DisplayName("문제가 5개가 아니면 예외")
        void rejects_when_not_five_quizzes() {
            given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
            given(eliceClient.generate(any())).willReturn("{\"quizzes\": [%s]}".formatted(oxQuizJson()));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("5개가 아닙니다");
        }

        @Test
        @DisplayName("슬롯 순서(유형·난이도)가 기대와 다르면 예외")
        void rejects_when_slot_order_mismatches() {
            given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
            given(eliceClient.generate(any()))
                    .willReturn("{\"quizzes\": [%s, %s, %s, %s, %s]}"
                            .formatted(
                                    multipleChoiceQuizJson(),
                                    oxQuizJson(),
                                    oxQuizJson(),
                                    multipleChoiceQuizJson(),
                                    keywordBlankQuizJson()));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("유형/난이도가 예상과 다릅니다");
        }

        @Test
        @DisplayName("OX correctAnswer가 O/X가 아니면 예외")
        void rejects_invalid_ox_answer() {
            given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
            String invalidOx =
                    quizJson("OX", "EASY", "\"correctAnswer\": \"MAYBE\", \"choices\": null, \"answerKeywords\": null");
            given(eliceClient.generate(any()))
                    .willReturn("{\"quizzes\": [%s, %s, %s, %s, %s]}"
                            .formatted(
                                    invalidOx,
                                    oxQuizJson(),
                                    multipleChoiceQuizJson(),
                                    multipleChoiceQuizJson(),
                                    keywordBlankQuizJson()));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("O/X가 아닙니다");
        }

        @Test
        @DisplayName("사지선다 선택지가 4개가 아니면 예외")
        void rejects_when_choices_not_four() {
            given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
            String threeChoices = quizJson("MULTIPLE_CHOICE", "MEDIUM", """
                    "correctAnswer": null, "answerKeywords": null,
                    "choices": [
                      {"content": "a", "isCorrect": false},
                      {"content": "b", "isCorrect": true},
                      {"content": "c", "isCorrect": false}
                    ]
                    """);
            given(eliceClient.generate(any()))
                    .willReturn("{\"quizzes\": [%s, %s, %s, %s, %s]}"
                            .formatted(
                                    oxQuizJson(),
                                    oxQuizJson(),
                                    threeChoices,
                                    multipleChoiceQuizJson(),
                                    keywordBlankQuizJson()));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("4개가 아닙니다");
        }

        @Test
        @DisplayName("키워드 빈칸 answerKeywords가 비어 있으면 예외")
        void rejects_empty_answer_keywords() {
            given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
            String emptyKeywords = quizJson(
                    "KEYWORD_BLANK", "HARD", "\"correctAnswer\": null, \"choices\": null, \"answerKeywords\": []");
            given(eliceClient.generate(any()))
                    .willReturn("{\"quizzes\": [%s, %s, %s, %s, %s]}"
                            .formatted(
                                    oxQuizJson(),
                                    oxQuizJson(),
                                    multipleChoiceQuizJson(),
                                    multipleChoiceQuizJson(),
                                    emptyKeywords));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("answerKeywords가 비어 있습니다");
        }

        @Test
        @DisplayName("키워드 빈칸의 한 빈칸에 동의어가 하나도 없으면 예외")
        void rejects_answer_keywords_with_empty_synonym_group() {
            given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
            String emptySynonymGroup = quizJson(
                    "KEYWORD_BLANK", "HARD", "\"correctAnswer\": null, \"choices\": null, \"answerKeywords\": [[]]");
            given(eliceClient.generate(any()))
                    .willReturn("{\"quizzes\": [%s, %s, %s, %s, %s]}"
                            .formatted(
                                    oxQuizJson(),
                                    oxQuizJson(),
                                    multipleChoiceQuizJson(),
                                    multipleChoiceQuizJson(),
                                    emptySynonymGroup));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("빈 동의어 묶음");
        }

        @Test
        @DisplayName("explanationSummary가 정확히 3줄이 아니면 예외")
        void rejects_explanation_summary_not_three_lines() {
            given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
            String oneLineSummary = """
                    {
                      "type": "OX",
                      "difficulty": "EASY",
                      "questionText": "질문 본문",
                      "codeSnippet": null,
                      "explanationSummary": "[[PCB]] 한 줄짜리 요약.",
                      "explanationExample": null,
                      "wrongAnswerExplanation": "오답 해설",
                      "correctAnswer": "O", "choices": null, "answerKeywords": null,
                      "followUpQuestions": [{"content": "꼬리질문", "isPrimary": true}],
                      "derivedConcepts": ["개념1"],
                      "keywords": [{"keyword": "PCB", "description": "설명"}]
                    }
                    """;
            given(eliceClient.generate(any()))
                    .willReturn("{\"quizzes\": [%s, %s, %s, %s, %s]}"
                            .formatted(
                                    oneLineSummary,
                                    oxQuizJson(),
                                    multipleChoiceQuizJson(),
                                    multipleChoiceQuizJson(),
                                    keywordBlankQuizJson()));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("정확히 3줄이 아닙니다");
        }

        @Test
        @DisplayName("keywords에 없는 문자열을 마커로 쓰면 오타로 간주해 예외")
        void rejects_marker_not_in_keywords() {
            given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
            String typoMarker = """
                    {
                      "type": "OX",
                      "difficulty": "EASY",
                      "questionText": "질문 본문",
                      "codeSnippet": null,
                      "explanationSummary": "[[PCM]]는 요약 1줄.\\n요약 2줄.\\n요약 3줄.",
                      "explanationExample": null,
                      "wrongAnswerExplanation": "오답 해설",
                      "correctAnswer": "O", "choices": null, "answerKeywords": null,
                      "followUpQuestions": [{"content": "꼬리질문", "isPrimary": true}],
                      "derivedConcepts": ["개념1"],
                      "keywords": [{"keyword": "PCB", "description": "설명"}]
                    }
                    """;
            given(eliceClient.generate(any()))
                    .willReturn("{\"quizzes\": [%s, %s, %s, %s, %s]}"
                            .formatted(
                                    typoMarker,
                                    oxQuizJson(),
                                    multipleChoiceQuizJson(),
                                    multipleChoiceQuizJson(),
                                    keywordBlankQuizJson()));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("오타 의심");
        }

        @Test
        @DisplayName("keywords 중 어느 컬럼에도 마킹되지 않은 게 있으면 예외")
        void rejects_keyword_not_covered_by_any_marker() {
            given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
            String uncoveredKeyword = """
                    {
                      "type": "OX",
                      "difficulty": "EASY",
                      "questionText": "질문 본문",
                      "codeSnippet": null,
                      "explanationSummary": "[[PCB]]는 요약 1줄.\\n요약 2줄.\\n요약 3줄.",
                      "explanationExample": null,
                      "wrongAnswerExplanation": "오답 해설",
                      "correctAnswer": "O", "choices": null, "answerKeywords": null,
                      "followUpQuestions": [{"content": "꼬리질문", "isPrimary": true}],
                      "derivedConcepts": ["개념1"],
                      "keywords": [{"keyword": "PCB", "description": "설명"}, {"keyword": "페이지 폴트", "description": "설명"}]
                    }
                    """;
            given(eliceClient.generate(any()))
                    .willReturn("{\"quizzes\": [%s, %s, %s, %s, %s]}"
                            .formatted(
                                    uncoveredKeyword,
                                    oxQuizJson(),
                                    multipleChoiceQuizJson(),
                                    multipleChoiceQuizJson(),
                                    keywordBlankQuizJson()));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("어디에도 마킹되지 않았습니다");
        }

        @Test
        @DisplayName("동의어 여러 개가 등록된 빈칸도 정상 저장한다")
        void saves_multiple_synonyms_for_one_blank() {
            given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
            given(eliceClient.generate(any())).willReturn(validSetJson());

            service().generateStep("운영체제");

            ArgumentCaptor<Quiz> captor = ArgumentCaptor.forClass(Quiz.class);
            verify(quizRepository, times(5)).save(captor.capture());
            Quiz keywordBlankQuiz = captor.getAllValues().stream()
                    .filter(q -> q.getType() == QuizType.KEYWORD_BLANK)
                    .findFirst()
                    .orElseThrow();
            assertThat(keywordBlankQuiz.getAnswerKeywords()).hasSize(2); // 동의어 2개가 같은 슬롯(1)에 저장됨
            assertThat(keywordBlankQuiz.getAnswerKeywords())
                    .allSatisfy(k -> assertThat(k.getSlotOrder()).isEqualTo(1));
        }

        @Test
        @DisplayName("엘리스 응답이 JSON이 아니면 파싱 실패 예외")
        void rejects_non_json_response() {
            given(quizRepository.findMaxStepOrder()).willReturn(Optional.empty());
            given(eliceClient.generate(any())).willReturn("이건 JSON이 아니에요");

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("파싱하지 못했습니다");
        }
    }
}
