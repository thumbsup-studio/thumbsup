package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class QuizGenerationPromptBuilderTest {

    @Test
    @DisplayName("해설 키워드 마커를 세 컬럼 전체에서 한 번만 쓰고 우선순위에 따라 배치하도록 안내한다")
    void requires_one_marker_across_explanation_fields_in_priority_order() {
        String prompt = QuizGenerationPromptBuilder.build("운영체제");

        assertThat(prompt)
                .contains("해설 3개 컬럼 전체에서 정확히 한 번만 마킹")
                .contains("explanationSummary → explanationExample → wrongAnswerExplanation 우선순위");
    }

    @Test
    @DisplayName("꼬리질문 키워드 마커를 한 줄 답과 모든 블록 전체에서 한 번만 쓰고 우선순위에 따라 배치하도록 안내한다")
    void requires_one_marker_across_follow_up_fields_in_priority_order() {
        String prompt = QuizGenerationPromptBuilder.build("운영체제");

        assertThat(prompt)
                .contains("꼬리질문 keywords의 각 용어는 oneLineAnswer와 모든 blocks의 content 전체에서 정확히 한 번만 마킹")
                .contains("oneLineAnswer → blocks 배열 순서(displayOrder 오름차순) 우선순위");
    }
}
