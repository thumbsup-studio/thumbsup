package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.config.ClockConfig;
import studio.thumbsup.server.common.config.JpaAuditingConfig;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizType;

/** 새 Flyway가 기존 문제 73개를 빠짐없이 안전한 한 문장 힌트로 백필하는지 검증한다. */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@Import({ClockConfig.class, JpaAuditingConfig.class})
@ActiveProfiles("test")
class QuizHintMigrationTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final QuizRepository quizRepository;

    QuizHintMigrationTest(@Autowired QuizRepository quizRepository) {
        this.quizRepository = quizRepository;
    }

    @Test
    @DisplayName("기존 73문제 모두 유형과 관계없이 검증된 한 문장 힌트를 가진다")
    void backfills_safe_hint_for_every_seeded_quiz() {
        List<Quiz> quizzes = quizRepository.findAll();

        assertThat(quizzes).hasSize(73);
        assertThat(quizzes)
                .extracting(Quiz::getType)
                .contains(QuizType.OX, QuizType.MULTIPLE_CHOICE, QuizType.KEYWORD_BLANK);
        assertThat(quizzes).allSatisfy(quiz -> {
            assertThat(quiz.getHint()).isNotBlank();
            assertThatCode(() -> QuizHintValidator.validate(
                            "step %d slot %d".formatted(quiz.getStepOrder(), quiz.getSlotOrder()), quiz))
                    .doesNotThrowAnyException();
        });
        assertThat(quizRepository
                        .findByStepOrderAndSlotOrder(11, 2)
                        .orElseThrow()
                        .getQuestionText())
                .isEqualTo("유닉스 계열의 계층형 이름 공간에서는 하나의 파일이 반드시 하나의 경로로만 접근 가능하므로, 같은 파일을 여러 디렉터리에서 공유할 수 없다.");
    }
}
