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

    @Test
    @DisplayName("레벨을 지정하지 않으면(단일 인자 오버로드) STANDARD와 동일하게 콘텐츠 난이도 힌트가 없다")
    void defaults_to_standard_when_level_omitted() {
        String prompt = QuizGenerationPromptBuilder.build("운영체제");

        assertThat(prompt).doesNotContain("콘텐츠 난이도: 입문자 수준").doesNotContain("콘텐츠 난이도: 심화 수준");
    }

    @Test
    @DisplayName("BASIC이면 유형별로 쉬운 콘텐츠를 요구하는 힌트가 들어간다")
    void includes_basic_level_hint_per_type() {
        String prompt = QuizGenerationPromptBuilder.build("운영체제", GenerationLevel.BASIC);

        assertThat(prompt)
                .contains("콘텐츠 난이도: 입문자 수준으로 맞춰라")
                .contains("OX: 가장 널리 알려진 기본 사실")
                .contains("사지선다: 오답 선택지도 명백히 틀린 것 위주")
                .contains("키워드 빈칸: 교재 도입부에 나올 법한 가장 기본적인 핵심 용어")
                .doesNotContain("콘텐츠 난이도: 심화 수준");
    }

    @Test
    @DisplayName("ADVANCED면 유형별로 심화 콘텐츠를 요구하는 힌트가 들어간다")
    void includes_advanced_level_hint_per_type() {
        String prompt = QuizGenerationPromptBuilder.build("운영체제", GenerationLevel.ADVANCED);

        assertThat(prompt)
                .contains("콘텐츠 난이도: 심화 수준으로 맞춰라")
                .contains("OX: 단순 정의가 아니라 실무자도 자주 오해하는 경계 사례")
                .contains("사지선다: 오답 선택지도 정답과 근접한 개념")
                .contains("키워드 빈칸: 실무·심화 문헌에서 쓰이는 전문 용어")
                .doesNotContain("콘텐츠 난이도: 입문자 수준");
    }

    @Test
    @DisplayName("레벨과 무관하게 슬롯 구성(하2·중2·상1)은 그대로 유지된다")
    void keeps_slot_composition_regardless_of_level() {
        for (GenerationLevel level : GenerationLevel.values()) {
            String prompt = QuizGenerationPromptBuilder.build("운영체제", level);

            assertThat(prompt)
                    .contains("1. EASY(OX)")
                    .contains("3. MEDIUM(MULTIPLE_CHOICE)")
                    .contains("5. HARD(KEYWORD_BLANK)");
        }
    }

    @Test
    @DisplayName("모든 유형에 한 문장 힌트와 유형별 정답 누출 금지 규칙을 요구한다")
    void requires_safe_one_sentence_hint_for_every_type() {
        String prompt = QuizGenerationPromptBuilder.build("운영체제");

        assertThat(prompt)
                .contains("\"hint\"")
                .contains("200자 이내")
                .contains("개행 없는 한 문장")
                .contains("OX")
                .contains("판단 결론")
                .contains("선택지 라벨")
                .contains("정답 키워드와 동의어");
    }
}
