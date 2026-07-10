package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture.keywordBlankQuizJson;
import static studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture.multipleChoiceQuizJson;
import static studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture.oxQuizJson;
import static studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture.quizJson;
import static studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture.setJsonWithFirstQuiz;
import static studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture.validSetJson;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 문제 세트의 스키마·해설·타입별 필드 검증을 다룬다.
 * 꼬리질문 상세(#133)의 검증은 {@link QuizGenerationFollowUpValidationTest}가 담당한다.
 */
@ExtendWith(MockitoExtension.class)
class QuizGenerationServiceTest {

    @Mock
    private EliceClient eliceClient;

    @Mock
    private QuizPersister quizPersister;

    private final ObjectMapper objectMapper = new ObjectMapper();

    private QuizGenerationService service() {
        return new QuizGenerationService(eliceClient, quizPersister, objectMapper);
    }

    @Nested
    @DisplayName("정상 생성")
    class GenerateStep {

        @Test
        @DisplayName("유효한 응답이면 검증 후 QuizPersister에 저장을 위임하고 결과를 그대로 반환한다")
        void delegates_to_persister_and_returns_its_result() {
            given(eliceClient.generate(any())).willReturn(validSetJson());
            given(quizPersister.persist(any(), any())).willReturn(4);

            int stepOrder = service().generateStep("운영체제");

            assertThat(stepOrder).isEqualTo(4);
            verify(quizPersister).persist(org.mockito.ArgumentMatchers.eq("운영체제"), any());
        }

        @Test
        @DisplayName("마크다운 코드펜스로 감싸진 응답도 파싱해 저장을 위임한다")
        void strips_markdown_fence_before_parsing() {
            given(eliceClient.generate(any())).willReturn("```json\n" + validSetJson() + "\n```");
            given(quizPersister.persist(any(), any())).willReturn(1);

            assertThat(service().generateStep("운영체제")).isEqualTo(1);
            verify(quizPersister).persist(any(), any());
        }

        @Test
        @DisplayName("서로 다른 키워드를 해설 3개 컬럼에 나눠 한 번씩 마킹하면 저장한다")
        void accepts_distinct_keywords_distributed_across_explanation_fields() {
            String distributedMarkers = oxQuizJson()
                    .replace("\"explanationExample\": null", "\"explanationExample\": \"[[페이지 폴트]] 적용 예시\"")
                    .replace(
                            "\"keywords\": [{\"keyword\": \"PCB\", \"description\": \"설명\"}]",
                            "\"keywords\": [{\"keyword\": \"PCB\", \"description\": \"설명\"}, "
                                    + "{\"keyword\": \"페이지 폴트\", \"description\": \"설명\"}]");
            given(eliceClient.generate(any())).willReturn(setJsonWithFirstQuiz(distributedMarkers));
            given(quizPersister.persist(any(), any())).willReturn(1);

            assertThat(service().generateStep("운영체제")).isEqualTo(1);
            verify(quizPersister).persist(any(), any());
        }
    }

    @Nested
    @DisplayName("검증 실패 — 저장을 시도하지 않는다")
    class ValidationFailure {

        @Test
        @DisplayName("문제가 5개가 아니면 예외")
        void rejects_when_not_five_quizzes() {
            given(eliceClient.generate(any())).willReturn("{\"quizzes\": [%s]}".formatted(oxQuizJson()));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("5개가 아닙니다");
            verify(quizPersister, never()).persist(any(), any());
        }

        @Test
        @DisplayName("슬롯 순서(유형·난이도)가 기대와 다르면 예외")
        void rejects_when_slot_order_mismatches() {
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
            String invalidOx = quizJson(
                    "OX", "EASY", "질문 본문", "\"correctAnswer\": \"MAYBE\", \"choices\": null, \"answerKeywords\": null");
            given(eliceClient.generate(any())).willReturn(setJsonWithFirstQuiz(invalidOx));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("O/X가 아닙니다");
        }

        @Test
        @DisplayName("사지선다 선택지가 4개가 아니면 예외")
        void rejects_when_choices_not_four() {
            String threeChoices = quizJson("MULTIPLE_CHOICE", "MEDIUM", "질문 본문", """
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
            String emptyKeywords = quizJson(
                    "KEYWORD_BLANK",
                    "HARD",
                    "빈칸 ___ 채우기 문제",
                    "\"correctAnswer\": null, \"choices\": null, \"answerKeywords\": []");
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
            String emptySynonymGroup = quizJson(
                    "KEYWORD_BLANK",
                    "HARD",
                    "빈칸 ___ 채우기 문제",
                    "\"correctAnswer\": null, \"choices\": null, \"answerKeywords\": [[]]");
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
        @DisplayName("빈칸(___) 개수와 answerKeywords 길이가 다르면 예외")
        void rejects_when_blank_count_mismatches_answer_keywords_length() {
            String mismatched = quizJson(
                    "KEYWORD_BLANK",
                    "HARD",
                    "빈칸 ___ 채우기 문제 (빈칸 1개)",
                    "\"correctAnswer\": null, \"choices\": null, " + "\"answerKeywords\": [[\"LIFO\"], [\"여분 정답\"]]");
            given(eliceClient.generate(any()))
                    .willReturn("{\"quizzes\": [%s, %s, %s, %s, %s]}"
                            .formatted(
                                    oxQuizJson(),
                                    oxQuizJson(),
                                    multipleChoiceQuizJson(),
                                    multipleChoiceQuizJson(),
                                    mismatched));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("빈칸 개수");
        }

        @Test
        @DisplayName("explanationSummary가 정확히 3줄이 아니면 예외")
        void rejects_explanation_summary_not_three_lines() {
            String oneLineSummary =
                    oxQuizJson().replace("[[PCB]]는 핵심 요약 1줄.\\n핵심 요약 2줄.\\n핵심 요약 3줄.", "[[PCB]] 한 줄짜리 요약.");
            given(eliceClient.generate(any())).willReturn(setJsonWithFirstQuiz(oneLineSummary));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("정확히 3줄이 아닙니다");
        }

        @Test
        @DisplayName("explanationSummary 줄 끝에 공백이 있으면 예외")
        void rejects_explanation_summary_with_trailing_whitespace() {
            String trailingWhitespace = oxQuizJson()
                    .replace(
                            "[[PCB]]는 핵심 요약 1줄.\\n핵심 요약 2줄.\\n핵심 요약 3줄.",
                            "[[PCB]]는 핵심 요약 1줄. \\n핵심 요약 2줄.\\n핵심 요약 3줄.");
            given(eliceClient.generate(any())).willReturn(setJsonWithFirstQuiz(trailingWhitespace));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("정확히 3줄이 아닙니다");
        }

        @Test
        @DisplayName("keywords에 없는 문자열을 마커로 쓰면 오타로 간주해 예외")
        void rejects_marker_not_in_keywords() {
            String typoMarker = oxQuizJson().replace("[[PCB]]는 핵심 요약", "[[PCM]]는 핵심 요약");
            given(eliceClient.generate(any())).willReturn(setJsonWithFirstQuiz(typoMarker));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("오타 의심");
        }

        @Test
        @DisplayName("keywords 중 어느 컬럼에도 마킹되지 않은 게 있으면 예외")
        void rejects_keyword_not_covered_by_any_marker() {
            String uncoveredKeyword = oxQuizJson()
                    .replace(
                            "\"keywords\": [{\"keyword\": \"PCB\", \"description\": \"설명\"}]",
                            "\"keywords\": [{\"keyword\": \"PCB\", \"description\": \"설명\"}, "
                                    + "{\"keyword\": \"페이지 폴트\", \"description\": \"설명\"}]");
            given(eliceClient.generate(any())).willReturn(setJsonWithFirstQuiz(uncoveredKeyword));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("어디에도 마킹되지 않았습니다");
        }

        @Test
        @DisplayName("같은 키워드를 해설 3개 컬럼 사이에서 중복 마킹하면 예외")
        void rejects_duplicate_keyword_marker_across_explanation_fields() {
            String duplicatedAcrossFields =
                    oxQuizJson().replace("\"explanationExample\": null", "\"explanationExample\": \"[[PCB]] 적용 예시\"");
            given(eliceClient.generate(any())).willReturn(setJsonWithFirstQuiz(duplicatedAcrossFields));

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("해설 3개 컬럼에서 같은 키워드가 두 번 이상 마킹됐습니다")
                    .hasMessageContaining("[[PCB]]");
            verify(quizPersister, never()).persist(any(), any());
        }

        @Test
        @DisplayName("엘리스 응답이 JSON이 아니면 파싱 실패 예외")
        void rejects_non_json_response() {
            given(eliceClient.generate(any())).willReturn("이건 JSON이 아니에요");

            assertThatThrownBy(() -> service().generateStep("운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("파싱하지 못했습니다");
        }
    }
}
