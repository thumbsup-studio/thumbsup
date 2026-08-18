package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import studio.thumbsup.server.common.support.RepositoryTestSupport;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizType;

/** 새 Flyway가 기존 문제 70개를 빠짐없이 안전한 한 문장 힌트로 백필하는지 검증한다. */
class QuizHintMigrationTest extends RepositoryTestSupport {

    private final QuizRepository quizRepository;

    QuizHintMigrationTest(@Autowired QuizRepository quizRepository) {
        this.quizRepository = quizRepository;
    }

    @Test
    @DisplayName("기존 70문제 모두 유형과 관계없이 검증된 한 문장 힌트를 가진다")
    void backfills_safe_hint_for_every_seeded_quiz() {
        List<Quiz> quizzes = quizRepository.findAll();

        assertThat(quizzes).hasSize(70);
        assertThat(quizzes)
                .extracting(Quiz::getType)
                .contains(QuizType.OX, QuizType.MULTIPLE_CHOICE, QuizType.KEYWORD_BLANK);
        assertThat(quizzes).allSatisfy(quiz -> {
            assertThat(quiz.getHint()).isNotBlank();
            assertThatCode(() -> QuizHintValidator.validate(
                            "step %d slot %d".formatted(quiz.getStepOrder(), quiz.getSlotOrder()), quiz))
                    .doesNotThrowAnyException();
        });
        // 마이그레이션 전 stepOrder=11·slotOrder=2였던 특정 문제(전역 순번)는 #292로 코스 상대 순번이 되며
        // 값이 바뀔 수 있으므로, 본문 텍스트로 직접 찾아 내용이 보존됐는지만 검증한다.
        assertThat(quizzes)
                .filteredOn(quiz -> quiz.getQuestionText()
                        .equals("유닉스 계열의 계층형 이름 공간에서는 하나의 파일이 반드시 하나의 경로로만 접근 가능하므로, " + "같은 파일을 여러 디렉터리에서 공유할 수 없다."))
                .hasSize(1);
    }
}
