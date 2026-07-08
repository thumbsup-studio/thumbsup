package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
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

/**
 * Repository 통합 테스트 — 실제 MySQL(Testcontainers)에 Flyway 마이그레이션을 적용해
 * 문제 유형별 자식 데이터 저장·조립을 검증한다 (피라미드 3층).
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@Import({ClockConfig.class, JpaAuditingConfig.class})
@ActiveProfiles("test")
class QuizRepositoryTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final QuizRepository quizRepository;

    QuizRepositoryTest(@Autowired QuizRepository quizRepository) {
        this.quizRepository = quizRepository;
    }

    @Nested
    @DisplayName("OX 문제 저장")
    class SaveOxQuiz {

        @Test
        @DisplayName("정답과 자식 데이터(꼬리질문·파생개념·키워드)가 함께 저장된다")
        void saves_with_children() {
            Quiz saved = quizRepository.save(QuizFixture.oxQuiz());

            Quiz found = quizRepository.findById(saved.getId()).orElseThrow();
            assertThat(found.getType()).isEqualTo(QuizType.OX);
            assertThat(found.getCorrectAnswer()).isEqualTo("O");
            assertThat(found.getFollowUpQuestions()).hasSize(1);
            assertThat(found.getDerivedConcepts()).hasSize(1);
            assertThat(found.getKeywords()).hasSize(1);
            assertThat(found.getChoices()).isEmpty();
            assertThat(found.getAnswerKeywords()).isEmpty();
        }
    }

    @Nested
    @DisplayName("사지선다 문제 저장")
    class SaveMultipleChoiceQuiz {

        @Test
        @DisplayName("선택지 4개가 순서·정답 여부와 함께 저장된다")
        void saves_choices_in_order() {
            Quiz saved = quizRepository.save(QuizFixture.multipleChoiceQuiz());

            Quiz found = quizRepository.findById(saved.getId()).orElseThrow();
            assertThat(found.getChoices()).hasSize(4);
            assertThat(found.getChoices())
                    .extracting(QuizChoice::getDisplayOrder)
                    .containsExactly(1, 2, 3, 4);
            assertThat(found.getChoices())
                    .filteredOn(QuizChoice::isCorrect)
                    .extracting(QuizChoice::getContent)
                    .containsExactly("O(n^2)");
        }
    }

    @Nested
    @DisplayName("키워드 빈칸 문제 저장")
    class SaveKeywordBlankQuiz {

        @Test
        @DisplayName("정답 키워드가 슬롯 순서대로 저장된다")
        void saves_answer_keywords() {
            Quiz saved = quizRepository.save(QuizFixture.keywordBlankQuiz());

            Quiz found = quizRepository.findById(saved.getId()).orElseThrow();
            assertThat(found.getAnswerKeywords()).hasSize(1);
            assertThat(found.getAnswerKeywords().get(0).getKeyword()).isEqualTo("LIFO");
        }
    }

    @Test
    @DisplayName("감사 필드는 저장 시 자동으로 채워진다")
    void audit_fields_are_populated_on_save() {
        Quiz saved = quizRepository.save(QuizFixture.oxQuiz());

        assertThat(saved.getCreatedAt()).isNotNull();
        assertThat(saved.getUpdatedAt()).isNotNull();
    }

    @Test
    @DisplayName("퀴즈 삭제 시 자식 데이터도 함께 삭제된다(cascade)")
    void deleting_quiz_cascades_to_children() {
        Quiz saved = quizRepository.save(QuizFixture.multipleChoiceQuiz());
        Long id = saved.getId();

        quizRepository.delete(saved);
        quizRepository.flush();

        assertThat(quizRepository.findById(id)).isEmpty();
    }
}
