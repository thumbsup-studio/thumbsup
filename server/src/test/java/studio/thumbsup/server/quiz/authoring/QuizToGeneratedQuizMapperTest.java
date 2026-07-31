package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.tuple;
import static studio.thumbsup.server.quiz.QuizFixture.keywordBlankQuiz;
import static studio.thumbsup.server.quiz.QuizFixture.multipleChoiceQuiz;
import static studio.thumbsup.server.quiz.QuizFixture.oxQuiz;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import studio.thumbsup.server.quiz.FollowUpBlockType;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizFollowUpQuestion;
import studio.thumbsup.server.quiz.QuizType;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;

class QuizToGeneratedQuizMapperTest {

    @Nested
    @DisplayName("공통 필드")
    class CommonFields {

        @Test
        @DisplayName("type/difficulty/questionText/hint를 그대로 옮긴다")
        void copies_type_difficulty_and_question_text() {
            Quiz quiz = oxQuiz();

            GeneratedQuizSet.GeneratedQuiz generated = QuizToGeneratedQuizMapper.toGenerated(quiz);

            assertThat(generated.type()).isEqualTo(QuizType.OX);
            assertThat(generated.difficulty()).isEqualTo(QuizDifficulty.EASY);
            assertThat(generated.questionText()).isEqualTo(quiz.getQuestionText());
            assertThat(generated.hint()).isEqualTo(quiz.getHint());
        }

        @Test
        @DisplayName("꼬리질문의 blocks를 (label, content)로 보존한다")
        void preserves_follow_up_blocks() {
            Quiz quiz = oxQuiz();
            QuizFollowUpQuestion followUp = quiz.getFollowUpQuestions().get(0);
            followUp.attachDetail(QuizDifficulty.EASY, "한 줄 답");
            followUp.addBlock("해설", FollowUpBlockType.TEXT, "블록 본문", 1);

            GeneratedQuizSet.GeneratedQuiz generated = QuizToGeneratedQuizMapper.toGenerated(quiz);

            assertThat(generated.followUpQuestions()).hasSize(1);
            assertThat(generated.followUpQuestions().get(0).blocks())
                    .extracting(
                            GeneratedQuizSet.GeneratedFollowUpBlock::label,
                            GeneratedQuizSet.GeneratedFollowUpBlock::content)
                    .containsExactly(tuple("해설", "블록 본문"));
        }
    }

    @Nested
    @DisplayName("사지선다")
    class MultipleChoice {

        @Test
        @DisplayName("choices 4개와 정답 1개를 보존한다")
        void preserves_choices_and_correct_answer() {
            Quiz quiz = multipleChoiceQuiz();

            GeneratedQuizSet.GeneratedQuiz generated = QuizToGeneratedQuizMapper.toGenerated(quiz);

            assertThat(generated.choices()).hasSize(4);
            assertThat(generated.choices())
                    .filteredOn(GeneratedQuizSet.GeneratedChoice::isCorrect)
                    .extracting(GeneratedQuizSet.GeneratedChoice::content)
                    .containsExactly("O(n^2)");
        }
    }

    @Nested
    @DisplayName("키워드 빈칸")
    class KeywordBlank {

        @Test
        @DisplayName("answerKeywords를 slotOrder별로 그룹핑한다(동의어 유지)")
        void groups_answer_keywords_by_slot_order() {
            Quiz quiz = keywordBlankQuiz(); // 슬롯 1: "LIFO"
            quiz.addAnswerKeyword(1, "Last In First Out"); // 슬롯 1 동의어
            quiz.addAnswerKeyword(2, "스택"); // 슬롯 2 (그룹 분리 확인용)

            GeneratedQuizSet.GeneratedQuiz generated = QuizToGeneratedQuizMapper.toGenerated(quiz);

            assertThat(generated.answerKeywords()).hasSize(2);
            assertThat(generated.answerKeywords().get(0)).containsExactly("LIFO", "Last In First Out");
            assertThat(generated.answerKeywords().get(1)).containsExactly("스택");
        }
    }
}
