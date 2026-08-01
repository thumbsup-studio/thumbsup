package studio.thumbsup.server.quiz.dto;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizType;

class QuizNextResponseTest {

    @Nested
    @DisplayName("빈칸 수 매핑")
    class BlankCountMapping {

        @Test
        @DisplayName("하나의 빈칸에 동의어가 여러 개여도 빈칸 수는 1이다")
        void counts_one_slot_when_blank_has_synonyms() {
            Quiz quiz = quiz(QuizType.KEYWORD_BLANK, "운영체제의 보호 기능을 요청하는 인터페이스를 ___이라고 한다.");
            quiz.addAnswerKeyword(1, "시스템 콜");
            quiz.addAnswerKeyword(1, "시스템 호출");

            QuizNextResponse response = QuizNextResponse.from(quiz);

            assertThat(response.blankCount()).isEqualTo(1);
        }

        @Test
        @DisplayName("여러 빈칸에 각각 동의어가 있어도 고유 슬롯 수를 반환한다")
        void counts_distinct_slots_when_multiple_blanks_have_synonyms() {
            Quiz quiz = quiz(QuizType.KEYWORD_BLANK, "프로세스는 ___에 적재되고 ___가 실행 단위를 관리한다.");
            quiz.addAnswerKeyword(1, "메모리");
            quiz.addAnswerKeyword(1, "주기억장치");
            quiz.addAnswerKeyword(2, "운영체제");
            quiz.addAnswerKeyword(2, "OS");

            QuizNextResponse response = QuizNextResponse.from(quiz);

            assertThat(response.blankCount()).isEqualTo(2);
        }

        @Test
        @DisplayName("OX와 사지선다 문제는 빈칸 수를 반환하지 않는다")
        void returns_null_for_non_keyword_blank_quizzes() {
            Quiz oxQuiz = quiz(QuizType.OX, "TCP는 연결 지향 프로토콜이다.");
            Quiz multipleChoiceQuiz = quiz(QuizType.MULTIPLE_CHOICE, "운영체제의 역할로 옳은 것은?");

            assertThat(QuizNextResponse.from(oxQuiz).blankCount()).isNull();
            assertThat(QuizNextResponse.from(multipleChoiceQuiz).blankCount()).isNull();
        }
    }

    private static Quiz quiz(QuizType type, String questionText) {
        Quiz quiz = Quiz.create(type, QuizDifficulty.HARD, questionText, null, "해설", null, "오답 해설");
        quiz.assignHint("판단에 필요한 핵심 조건을 떠올려 보세요.");
        return quiz;
    }
}
