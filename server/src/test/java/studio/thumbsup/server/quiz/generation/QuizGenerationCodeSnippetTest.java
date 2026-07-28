package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture.oxQuizJson;
import static studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture.setJsonWithFirstQuiz;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class QuizGenerationCodeSnippetTest {

    @Mock
    private EliceClient eliceClient;

    @Mock
    private QuizPersister quizPersister;

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final GeneratedQuizValidator validator = new GeneratedQuizValidator(objectMapper);

    @Nested
    @DisplayName("퀴즈 생성")
    class GenerateQuiz {

        @Test
        @DisplayName("코드 구조가 있는 codeSnippet은 검증 후 저장한다")
        void persists_generated_quiz_with_valid_code_snippet() throws Exception {
            given(eliceClient.generate(any())).willReturn(setJsonWithFirstCodeSnippet("int value = 1;\nvalue++;"));
            given(quizPersister.persist(any(), any(), any())).willReturn(4);

            int stepOrder = service().generateStep(1L, "운영체제");

            assertThat(stepOrder).isEqualTo(4);
            verify(quizPersister).persist(any(), any(), any());
        }

        @Test
        @DisplayName("자연어만 있는 codeSnippet은 저장 전에 거부한다")
        void rejects_generated_quiz_with_natural_language_snippet() throws Exception {
            String naturalLanguageSnippet = """
                    프로세스: P1(우선순위 3), P2(우선순위 1), P3(우선순위 2)
                    가정: 숫자가 작을수록 우선순위가 높고, 모두 같은 시각에 준비 상태가 된다.
                    스케줄링: 비선점형 우선순위 스케줄링
                    """;
            given(eliceClient.generate(any())).willReturn(setJsonWithFirstCodeSnippet(naturalLanguageSnippet));

            assertThatThrownBy(() -> service().generateStep(1L, "운영체제"))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("codeSnippet");
            verify(quizPersister, never()).persist(any(), any(), any());
        }

        @Test
        @DisplayName("프롬프트는 코드가 아닌 지문을 questionText에 작성하고 codeSnippet을 null로 두도록 안내한다")
        void prompt_requires_null_code_snippet_for_non_code_context() {
            String prompt = QuizGenerationPromptBuilder.build("운영체제");

            assertThat(prompt)
                    .doesNotContain("가능하면 코드 지문")
                    .contains(
                            "실제 코드나 실행 흐름이 명확한 의사코드",
                            "필요할 때만",
                            "codeSnippet은 반드시 null",
                            "자연어 상황 설명",
                            "표",
                            "조건 목록",
                            "리터럴 입력값만 대입",
                            "questionText");
        }
    }

    private QuizGenerationService service() {
        return new QuizGenerationService(eliceClient, quizPersister, validator);
    }

    private String setJsonWithFirstCodeSnippet(String codeSnippet) throws JsonProcessingException {
        String codeSnippetJson = objectMapper.writeValueAsString(codeSnippet);
        String firstQuiz = oxQuizJson().replace("\"codeSnippet\": null", "\"codeSnippet\": " + codeSnippetJson);
        return setJsonWithFirstQuiz(firstQuiz);
    }
}
