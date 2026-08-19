package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import studio.thumbsup.server.quiz.QuizStepBriefingBlockType;

class GeneratedStepBriefingValidationTest {

    private final GeneratedQuizValidator validator = new GeneratedQuizValidator(new ObjectMapper());

    @Nested
    @DisplayName("스텝 브리핑 검증")
    class ValidateBriefing {

        @Test
        @DisplayName("2개 이상의 순서 있는 브리핑 블록을 허용한다")
        void accepts_valid_briefing() {
            assertThatCode(() -> validator.validateBriefing(validBriefing())).doesNotThrowAnyException();
        }

        @Test
        @DisplayName("대소문자만 다른 heading 중복을 거부한다")
        void rejects_duplicate_heading() {
            GeneratedQuizSet.GeneratedBriefing briefing = new GeneratedQuizSet.GeneratedBriefing(
                    "요약",
                    List.of(
                            new GeneratedQuizSet.GeneratedBriefingBlock(QuizStepBriefingBlockType.CONCEPT, "핵심", "내용"),
                            new GeneratedQuizSet.GeneratedBriefingBlock(
                                    QuizStepBriefingBlockType.EXAMPLE, "핵심", "예시")));

            assertThatThrownBy(() -> validator.validateBriefing(briefing))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("heading이 중복");
        }

        @Test
        @DisplayName("빈 summary와 허용 범위를 벗어난 블록 수를 거부한다")
        void rejects_empty_summary_and_invalid_block_count() {
            assertThatThrownBy(() ->
                            validator.validateBriefing(new GeneratedQuizSet.GeneratedBriefing(" ", validBlocks())))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("summary이 비어");
            assertThatThrownBy(() -> validator.validateBriefing(new GeneratedQuizSet.GeneratedBriefing(
                            "요약", List.of(validBlocks().getFirst()))))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("2~4개");
            assertThatThrownBy(() -> validator.validateBriefing(new GeneratedQuizSet.GeneratedBriefing(
                            "요약",
                            List.of(
                                    validBlocks().getFirst(),
                                    validBlocks().get(1),
                                    validBlocks().getFirst(),
                                    validBlocks().get(1),
                                    validBlocks().getFirst()))))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("2~4개");
        }

        @Test
        @DisplayName("type 누락과 heading·content 길이 초과를 거부한다")
        void rejects_missing_type_and_too_long_text() {
            assertThatThrownBy(() -> validator.validateBriefing(new GeneratedQuizSet.GeneratedBriefing(
                            "요약",
                            List.of(
                                    new GeneratedQuizSet.GeneratedBriefingBlock(null, "핵심", "내용"),
                                    validBlocks().get(1)))))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("type이 비어");
            assertThatThrownBy(() -> validator.validateBriefing(new GeneratedQuizSet.GeneratedBriefing(
                            "요약",
                            List.of(
                                    new GeneratedQuizSet.GeneratedBriefingBlock(
                                            QuizStepBriefingBlockType.CONCEPT, "가".repeat(101), "내용"),
                                    validBlocks().get(1)))))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("heading은 100자 이하");
            assertThatThrownBy(() -> validator.validateBriefing(new GeneratedQuizSet.GeneratedBriefing(
                            "요약",
                            List.of(
                                    new GeneratedQuizSet.GeneratedBriefingBlock(
                                            QuizStepBriefingBlockType.CONCEPT, "핵심", "가".repeat(2001)),
                                    validBlocks().get(1)))))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("content은 2000자 이하");
        }

        @Test
        @DisplayName("구형 schemaVersion은 문제 세트가 정상이어도 스텝 콘텐츠로 거부한다")
        void rejects_legacy_schema_version() {
            GeneratedQuizSet legacySet = validator.parse(stepContentJson(1));

            assertThatThrownBy(() -> validator.validateStepContent(legacySet, QuizPreset.BASIC_5))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("schemaVersion");
        }
    }

    private static GeneratedQuizSet.GeneratedBriefing validBriefing() {
        return new GeneratedQuizSet.GeneratedBriefing("프로세스의 실행 원리를 이해합니다.", validBlocks());
    }

    private static List<GeneratedQuizSet.GeneratedBriefingBlock> validBlocks() {
        return List.of(
                new GeneratedQuizSet.GeneratedBriefingBlock(
                        QuizStepBriefingBlockType.CONCEPT, "핵심", "프로세스는 실행 중인 프로그램입니다."),
                new GeneratedQuizSet.GeneratedBriefingBlock(
                        QuizStepBriefingBlockType.CAUTION, "주의", "프로그램 파일 자체와 구분해야 합니다."));
    }

    private static String stepContentJson(int schemaVersion) {
        String quizzesJson = GeneratedQuizJsonFixture.validSetJson().substring("{\"quizzes\":".length());
        return """
                {"schemaVersion":%d,"briefing":{"summary":"요약","blocks":[
                {"type":"CONCEPT","heading":"핵심","content":"내용"},
                {"type":"CAUTION","heading":"주의","content":"내용"}]},"quizzes":%s
                """.formatted(schemaVersion, quizzesJson);
    }
}
