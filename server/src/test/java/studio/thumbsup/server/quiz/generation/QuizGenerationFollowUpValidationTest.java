package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture.DEFAULT_BLOCKS;
import static studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture.DEFAULT_KEYWORDS;
import static studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture.DEFAULT_ONE_LINE_ANSWER;
import static studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture.followUpJson;
import static studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture.oxQuizJsonWith;
import static studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture.setJsonWithFirstQuiz;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

/**
 * 꼬리질문 상세(#133)의 생성 검증. 상세가 한 조각이라도 비면 조회 API가 그 꼬리질문을 응답에서 감추므로
 * (`hasDetail()`), 저장 전에 여기서 막지 못하면 꼬리질문이 조용히 사라진다.
 *
 * <p>부모 문제의 사전은 {@code PCB}, 꼬리질문의 사전은 {@code FIFO}다 — 두 사전이 섞이지 않는지가 핵심이다.
 */
@DisplayName("꼬리질문 상세 검증")
class QuizGenerationFollowUpValidationTest {

    private final GeneratedQuizValidator validator = new GeneratedQuizValidator(new ObjectMapper());

    /** 첫 슬롯의 꼬리질문만 갈아끼운 세트를 응답으로 준다 — 나머지는 항상 유효하다. */
    private String setJsonWithFirstQuizFollowUp(String followUpQuestionsJson) {
        return setJsonWithFirstQuiz(oxQuizJsonWith(followUpQuestionsJson));
    }

    private void assertRejected(String messageFragment) {
        assertThatThrownBy(() -> validateSet(currentResponse))
                .isInstanceOf(QuizGenerationException.class)
                .hasMessageContaining(messageFragment);
    }

    private String currentResponse;

    @Nested
    @DisplayName("필수 필드")
    class RequiredFields {

        @Test
        @DisplayName("difficulty가 없으면 예외 — 상세가 있다고 판정된 꼬리질문의 난이도가 null로 내려간다")
        void rejects_missing_difficulty() {
            givenFirstQuizFollowUp(
                    followUpJson("꼬리질문", "null", DEFAULT_ONE_LINE_ANSWER, DEFAULT_BLOCKS, DEFAULT_KEYWORDS));

            assertRejected("difficulty가 비어 있습니다");
        }

        @Test
        @DisplayName("oneLineAnswer가 비어 있으면 예외")
        void rejects_blank_one_line_answer() {
            givenFirstQuizFollowUp(followUpJson("꼬리질문", "\"MEDIUM\"", "", DEFAULT_BLOCKS, DEFAULT_KEYWORDS));

            assertRejected("oneLineAnswer가 비어 있습니다");
        }

        @Test
        @DisplayName("keywords가 비어 있으면 예외 — 하이라이트할 사전이 없다")
        void rejects_empty_keywords() {
            givenFirstQuizFollowUp(followUpJson("꼬리질문", "\"MEDIUM\"", "마커 없는 한 줄 답.", DEFAULT_BLOCKS, "[]"));

            assertRejected("keywords가 비어 있습니다");
        }

        @Test
        @DisplayName("빈 keyword와 빈 마커 조합도 저장 전에 거부한다")
        void rejects_blank_keyword_even_when_empty_marker_covers_it() {
            String blankKeyword = "[{\"keyword\": \"\", \"description\": \"설명\"}]";
            givenFirstQuizFollowUp(followUpJson("꼬리질문", "\"MEDIUM\"", "[[]]는 빈 키워드다.", DEFAULT_BLOCKS, blankKeyword));

            assertRejected("keywords[1].keyword가 비어 있습니다");
        }

        @Test
        @DisplayName("대표 꼬리질문이 정확히 1개가 아니면 예외")
        void rejects_when_primary_is_not_exactly_one() {
            String notPrimary = followUpJson(
                            "꼬리질문", "\"MEDIUM\"", DEFAULT_ONE_LINE_ANSWER, DEFAULT_BLOCKS, DEFAULT_KEYWORDS)
                    .replace("\"isPrimary\": true", "\"isPrimary\": false");
            givenFirstQuizFollowUp(notPrimary);

            assertRejected("대표(isPrimary=true) 1개를 포함해야 합니다");
        }
    }

    @Nested
    @DisplayName("상세 정리 블록")
    class DetailBlocks {

        @Test
        @DisplayName("blocks가 비어 있으면 예외")
        void rejects_empty_blocks() {
            givenFirstQuizFollowUp(followUpJson("꼬리질문", "\"MEDIUM\"", DEFAULT_ONE_LINE_ANSWER, "[]", DEFAULT_KEYWORDS));

            assertRejected("blocks가 비어 있습니다");
        }

        @Test
        @DisplayName("첫 블록 label이 \"해설\"이 아니면 예외 — 그 뒤 블록의 라벨은 자유다")
        void rejects_when_first_block_label_is_not_the_fixed_one() {
            String wrongFirstLabel = "[{\"label\": \"실무 사용처\", \"content\": \"큐는 [[FIFO]] 순서다.\"}]";
            givenFirstQuizFollowUp(
                    followUpJson("꼬리질문", "\"MEDIUM\"", DEFAULT_ONE_LINE_ANSWER, wrongFirstLabel, DEFAULT_KEYWORDS));

            assertRejected("첫 블록 label");
        }

        @Test
        @DisplayName("첫 블록이 \"해설\"이면 뒤이어 어떤 라벨을 붙여도 통과한다")
        void accepts_any_label_after_the_first_block() {
            String blocks = "[{\"label\": \"해설\", \"content\": \"큐는 [[FIFO]] 순서다.\"},"
                    + " {\"label\": \"흔한 오해\", \"content\": \"스택과 헷갈리기 쉽다.\"}]";
            givenFirstQuizFollowUp(followUpJson("꼬리질문", "\"MEDIUM\"", "마커 없는 한 줄 답.", blocks, DEFAULT_KEYWORDS));

            assertValid();
        }
    }

    @Nested
    @DisplayName("마커")
    class Markers {

        @Test
        @DisplayName("질문 본문에 마커가 있으면 예외 — 서버가 평문으로 그대로 내려준다")
        void rejects_marker_in_question_content() {
            givenFirstQuizFollowUp(followUpJson(
                    "[[FIFO]] 꼬리질문", "\"MEDIUM\"", DEFAULT_ONE_LINE_ANSWER, DEFAULT_BLOCKS, DEFAULT_KEYWORDS));

            assertRejected("마커를 넣을 수 없습니다");
        }

        @Test
        @DisplayName("부모 문제의 키워드로 꼬리질문을 마킹하면 오타로 잡는다 — 사전은 꼬리질문마다 다르다")
        void rejects_marker_taken_from_the_parent_quiz_dictionary() {
            givenFirstQuizFollowUp(
                    followUpJson("꼬리질문", "\"MEDIUM\"", "[[PCB]]는 프로세스 제어 블록이다.", DEFAULT_BLOCKS, DEFAULT_KEYWORDS));

            assertRejected("오타 의심");
        }

        @Test
        @DisplayName("꼬리질문 keywords가 한 줄 답에도 블록에도 마킹되지 않으면 예외")
        void rejects_keyword_not_covered_anywhere() {
            String blocks = "[{\"label\": \"해설\", \"content\": \"마커 없는 블록 본문.\"}]";
            givenFirstQuizFollowUp(followUpJson("꼬리질문", "\"MEDIUM\"", "마커 없는 한 줄 답.", blocks, DEFAULT_KEYWORDS));

            assertRejected("어디에도 마킹되지 않았습니다");
        }

        @Test
        @DisplayName("한 블록 안에서 같은 키워드를 두 번 마킹하면 예외")
        void rejects_duplicate_marker_within_one_block() {
            String blocks = "[{\"label\": \"해설\", \"content\": \"[[FIFO]]는 큐의 순서다. [[FIFO]]를 다시 말한다.\"}]";
            givenFirstQuizFollowUp(followUpJson("꼬리질문", "\"MEDIUM\"", "마커 없는 한 줄 답.", blocks, DEFAULT_KEYWORDS));

            assertRejected("두 번 이상 마킹");
        }

        @Test
        @DisplayName("한 줄 답과 블록 사이에서 같은 키워드를 중복 마킹하면 예외")
        void rejects_duplicate_marker_across_one_line_answer_and_block() {
            String blocks = "[{\"label\": \"해설\", \"content\": \"큐는 [[FIFO]] 순서다.\"}]";
            givenFirstQuizFollowUp(
                    followUpJson("꼬리질문", "\"MEDIUM\"", DEFAULT_ONE_LINE_ANSWER, blocks, DEFAULT_KEYWORDS));

            assertRejected("한 줄 답과 상세 정리 블록에서 같은 키워드가 두 번 이상 마킹됐습니다: [[FIFO]]");
        }

        @Test
        @DisplayName("서로 다른 블록 사이에서 같은 키워드를 중복 마킹하면 예외")
        void rejects_duplicate_marker_across_blocks() {
            String blocks = "[{\"label\": \"해설\", \"content\": \"큐는 [[FIFO]] 순서다.\"},"
                    + " {\"label\": \"실무 사용처\", \"content\": \"작업 대기열은 [[FIFO]]로 처리한다.\"}]";
            givenFirstQuizFollowUp(followUpJson("꼬리질문", "\"MEDIUM\"", "마커 없는 한 줄 답.", blocks, DEFAULT_KEYWORDS));

            assertRejected("한 줄 답과 상세 정리 블록에서 같은 키워드가 두 번 이상 마킹됐습니다: [[FIFO]]");
        }

        @Test
        @DisplayName("서로 다른 키워드를 한 줄 답과 블록에 나눠 한 번씩 마킹하면 저장한다")
        void accepts_distinct_keywords_distributed_across_follow_up_fields() {
            String blocks = "[{\"label\": \"해설\", \"content\": \"[[작업 대기열]]은 요청을 순서대로 보관한다.\"}]";
            String keywords = "[{\"keyword\": \"FIFO\", \"description\": \"설명\"},"
                    + " {\"keyword\": \"작업 대기열\", \"description\": \"설명\"}]";
            givenFirstQuizFollowUp(followUpJson("꼬리질문", "\"MEDIUM\"", DEFAULT_ONE_LINE_ANSWER, blocks, keywords));

            assertValid();
        }

        @Test
        @DisplayName("서로 다른 꼬리질문은 사전과 마커 중복 범위를 독립적으로 검증한다")
        void accepts_same_keyword_once_in_each_follow_up_question() {
            String primary =
                    followUpJson("대표 꼬리질문", "\"MEDIUM\"", DEFAULT_ONE_LINE_ANSWER, DEFAULT_BLOCKS, DEFAULT_KEYWORDS);
            String secondary = followUpJson(
                            "보조 꼬리질문", "\"MEDIUM\"", DEFAULT_ONE_LINE_ANSWER, DEFAULT_BLOCKS, DEFAULT_KEYWORDS)
                    .replace("\"isPrimary\": true", "\"isPrimary\": false");
            givenFirstQuizFollowUp(primary + "," + secondary);

            assertValid();
        }
    }

    private void givenFirstQuizFollowUp(String followUpQuestionsJson) {
        currentResponse = setJsonWithFirstQuizFollowUp(followUpQuestionsJson);
    }

    private void assertValid() {
        assertThatCode(() -> validateSet(currentResponse)).doesNotThrowAnyException();
    }

    private void validateSet(String rawResponse) {
        validator.validateSet(validator.parse(rawResponse));
    }
}
