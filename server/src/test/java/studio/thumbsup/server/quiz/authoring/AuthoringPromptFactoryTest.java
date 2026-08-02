package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import studio.thumbsup.server.quiz.generation.QuizPreset;

class AuthoringPromptFactoryTest {

    @Nested
    @DisplayName("generatePrompt")
    class GeneratePrompt {

        @Test
        @DisplayName("시스템프롬프트와 주제·스키마를 포함한다")
        void generatePrompt는_시스템프롬프트와_주제_스키마를_포함한다() {
            String prompt = AuthoringPromptFactory.generatePrompt("운영체제");

            assertThat(prompt).contains("CS 강사"); // SYSTEM_PROMPT 병합 확인
            assertThat(prompt).contains("운영체제");
        }

        @Test
        @DisplayName("뼈대 맥락 프롬프트는 앞뒤 스텝과 기존 문제를 읽기 전용 맥락으로 넣는다")
        void context_prompt_includes_neighbours() {
            var context = new OutlineStepContext(
                    "운영체제 첫걸음",
                    3,
                    10,
                    "CPU 스케줄링",
                    "선점·비선점 스케줄링을 구분한다",
                    "프로세스와 스레드",
                    "프로세스 동기화",
                    List.of("문맥 교환 비용이 큰 이유는?"));

            String prompt = AuthoringPromptFactory.generatePrompt(context, QuizPreset.BASIC_5);

            assertThat(prompt)
                    .contains("운영체제 첫걸음")
                    .contains("3/10")
                    .contains("선점·비선점 스케줄링을 구분한다")
                    .contains("프로세스와 스레드")
                    .contains("프로세스 동기화")
                    .contains("문맥 교환 비용이 큰 이유는?");
        }

        @Test
        @DisplayName("앞뒤 스텝이 없는 첫·마지막 스텝은 해당 섹션을 아예 넣지 않는다")
        void omits_missing_neighbour_sections() {
            var context = new OutlineStepContext("코스", 1, 1, "주제", "목표", null, null, List.of());

            String prompt = AuthoringPromptFactory.generatePrompt(context, QuizPreset.BASIC_5);

            assertThat(prompt).doesNotContain("[앞 스텝]").doesNotContain("[뒤 스텝]");
        }

        @Test
        @DisplayName("뼈대 프롬프트는 목차 원문과 스텝 수 범위를 함께 지시한다")
        void outline_prompt_carries_toc_and_range() {
            String prompt = AuthoringPromptFactory.outlinePrompt("네트워크 기초", "네트워크", "1장 네트워크 첫걸음");

            assertThat(prompt)
                    .contains("네트워크 기초")
                    .contains("1장 네트워크 첫걸음")
                    .contains("3")
                    .contains("20");
        }
    }

    @Nested
    @DisplayName("reviewPrompt")
    class ReviewPrompt {

        @Test
        @DisplayName("피드백이 있으면 반영 섹션을 포함한다")
        void reviewPrompt는_피드백이_있으면_반영_섹션을_포함한다() {
            String prompt = AuthoringPromptFactory.reviewPrompt("운영체제", "{\"quizzes\":[]}", "선지 3번이 모호함", List.of());

            assertThat(prompt).contains("검수자 피드백");
            assertThat(prompt).contains("선지 3번이 모호함");
            assertThat(prompt).contains("reviewSummary");
            assertThat(prompt).contains("hint도 반드시 검수").contains("200자 이내").contains("빈칸 정답 키워드나 동의어");
        }

        @Test
        @DisplayName("피드백이 없고 형제문제가 있으면 형제문제 섹션만 포함한다")
        void reviewPrompt는_피드백_없고_형제문제_있으면_해당_섹션만() {
            String prompt =
                    AuthoringPromptFactory.reviewPrompt("운영체제", "{\"quizzes\":[]}", null, List.of("프로세스와 스레드의 차이는?"));

            assertThat(prompt).doesNotContain("검수자 피드백");
            assertThat(prompt).contains("다른 문제들");
            assertThat(prompt).contains("프로세스와 스레드의 차이는?");
        }

        @Test
        @DisplayName("피드백이 공백뿐이면 반영 섹션을 포함하지 않는다")
        void reviewPrompt는_피드백이_공백뿐이면_섹션을_제외한다() {
            String prompt = AuthoringPromptFactory.reviewPrompt("운영체제", "{\"quizzes\":[]}", "   ", List.of());

            assertThat(prompt).doesNotContain("검수자 피드백");
        }

        @Test
        @DisplayName("형제문제가 비어 있으면 다른 문제들 섹션을 포함하지 않는다")
        void reviewPrompt는_형제문제가_비어있으면_섹션을_제외한다() {
            String prompt = AuthoringPromptFactory.reviewPrompt("운영체제", "{\"quizzes\":[]}", null, List.of());

            assertThat(prompt).doesNotContain("다른 문제들");
        }
    }

    @Nested
    @DisplayName("AuthoringOutputSchemas")
    class OutputSchemas {

        @Test
        @DisplayName("GENERATE·REVIEW 상수는 유효한 JSON이다")
        void 출력_스키마_상수는_유효한_JSON이다() {
            ObjectMapper objectMapper = new ObjectMapper();

            assertThatCode(() -> objectMapper.readTree(AuthoringOutputSchemas.GENERATE))
                    .doesNotThrowAnyException();
            assertThatCode(() -> objectMapper.readTree(AuthoringOutputSchemas.REVIEW))
                    .doesNotThrowAnyException();
        }

        @Test
        @DisplayName("GENERATE·REVIEW 모두 hint를 필수 필드로 요구한다")
        void output_schemas_require_hint() throws Exception {
            ObjectMapper objectMapper = new ObjectMapper();

            assertThat(objectMapper.readTree(AuthoringOutputSchemas.GENERATE).toString())
                    .contains("hint");
            assertThat(objectMapper.readTree(AuthoringOutputSchemas.REVIEW).toString())
                    .contains("hint");
        }
    }
}
