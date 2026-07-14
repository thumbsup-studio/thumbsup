package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

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
    }
}
