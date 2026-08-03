package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizType;

class QuizPresetTest {

    @Nested
    @DisplayName("프리셋 슬롯 구성은")
    class Slots {

        @Test
        @DisplayName("BASIC_5는 기존 하드코딩 구성(OX·OX·객관식·객관식·빈칸)과 완전히 같다")
        void basic5_matches_legacy_composition() {
            assertThat(QuizPreset.BASIC_5.slots())
                    .containsExactly(
                            new QuizPreset.Slot(QuizType.OX, QuizDifficulty.EASY),
                            new QuizPreset.Slot(QuizType.OX, QuizDifficulty.EASY),
                            new QuizPreset.Slot(QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM),
                            new QuizPreset.Slot(QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM),
                            new QuizPreset.Slot(QuizType.KEYWORD_BLANK, QuizDifficulty.HARD));
            assertThat(QuizPreset.BASIC_5.quizCount()).isEqualTo(5);
            assertThat(QuizPreset.BASIC_5.estimatedMinutes()).isEqualTo(3);
        }

        @Test
        @DisplayName("LIGHT_3은 유형별 1문제씩 3개다")
        void light3_has_three_quizzes() {
            assertThat(QuizPreset.LIGHT_3.quizCount()).isEqualTo(3);
            assertThat(QuizPreset.LIGHT_3.estimatedMinutes()).isEqualTo(2);
            assertThat(QuizPreset.LIGHT_3.slots())
                    .extracting(QuizPreset.Slot::type)
                    .containsExactly(QuizType.OX, QuizType.MULTIPLE_CHOICE, QuizType.KEYWORD_BLANK);
        }

        @Test
        @DisplayName("DEEP_7은 객관식 3·빈칸 2로 7개다")
        void deep7_has_seven_quizzes() {
            assertThat(QuizPreset.DEEP_7.quizCount()).isEqualTo(7);
            assertThat(QuizPreset.DEEP_7.estimatedMinutes()).isEqualTo(5);
            assertThat(QuizPreset.DEEP_7.slots())
                    .filteredOn(slot -> slot.type() == QuizType.MULTIPLE_CHOICE)
                    .hasSize(3);
            assertThat(QuizPreset.DEEP_7.slots())
                    .filteredOn(slot -> slot.type() == QuizType.KEYWORD_BLANK)
                    .hasSize(2);
        }

        @Test
        @DisplayName("난이도는 유형과 항상 짝을 이룬다 — OX=EASY, 객관식=MEDIUM, 빈칸=HARD")
        void difficulty_always_matches_type() {
            for (QuizPreset preset : QuizPreset.values()) {
                assertThat(preset.slots()).allSatisfy(slot -> assertThat(slot.difficulty())
                        .isEqualTo(
                                switch (slot.type()) {
                                    case OX -> QuizDifficulty.EASY;
                                    case MULTIPLE_CHOICE -> QuizDifficulty.MEDIUM;
                                    case KEYWORD_BLANK -> QuizDifficulty.HARD;
                                }));
            }
        }
    }
}
