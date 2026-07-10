package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceException;
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
 * 꼬리질문 상세 컬럼·블록·키워드의 저장과 연쇄 삭제를 검증한다 (피라미드 3층).
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@Import({ClockConfig.class, JpaAuditingConfig.class})
@ActiveProfiles("test")
class QuizFollowUpQuestionRepositoryTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final QuizRepository quizRepository;
    private final QuizFollowUpQuestionRepository quizFollowUpQuestionRepository;
    private final EntityManager entityManager;

    QuizFollowUpQuestionRepositoryTest(
            @Autowired QuizRepository quizRepository,
            @Autowired QuizFollowUpQuestionRepository quizFollowUpQuestionRepository,
            @Autowired EntityManager entityManager) {
        this.quizRepository = quizRepository;
        this.quizFollowUpQuestionRepository = quizFollowUpQuestionRepository;
        this.entityManager = entityManager;
    }

    private long countRows(String table) {
        return ((Number) entityManager
                        .createNativeQuery("SELECT COUNT(*) FROM " + table)
                        .getSingleResult())
                .longValue();
    }

    /** 블록 2개·키워드 1개를 붙인 꼬리질문 하나를 가진 문제를 저장한다. 저작 순서와 표시 순서를 일부러 어긋나게 둔다. */
    private Quiz persistQuizWithDetailedFollowUpQuestion() {
        Quiz quiz = QuizFixture.oxQuiz();
        QuizFollowUpQuestion followUpQuestion = quiz.addFollowUpQuestion("큐와 스택의 차이는?", true, 2);
        followUpQuestion.attachDetail(QuizDifficulty.HARD, "스택은 [[LIFO]]입니다.");
        followUpQuestion.addKeyword("LIFO", "마지막에 넣은 데이터가 먼저 나오는 순서");
        followUpQuestion.addBlock("실무 사용처", FollowUpBlockType.TEXT, "함수 호출 스택이 대표적이다.", 2);
        followUpQuestion.addBlock("해설", FollowUpBlockType.TEXT, "한쪽 끝에서만 넣고 뺀다.", 1);

        return quizRepository.saveAndFlush(quiz);
    }

    /** 저장 직후 영속성 컨텍스트를 비워, 이어지는 조회가 DB를 실제로 다시 읽게 한다. */
    private Long persistAndDetach() {
        Long followUpQuestionId = persistQuizWithDetailedFollowUpQuestion()
                .getFollowUpQuestions()
                .get(1)
                .getId();
        entityManager.clear();
        return followUpQuestionId;
    }

    @Nested
    @DisplayName("꼬리질문 상세 저장")
    class SaveDetail {

        @Test
        @DisplayName("난이도·한 줄 답·블록·키워드가 함께 저장되고 블록은 표시 순서대로 읽힌다")
        void persists_detail_with_ordered_blocks() {
            Long followUpQuestionId = persistAndDetach();

            QuizFollowUpQuestion found =
                    quizFollowUpQuestionRepository.findById(followUpQuestionId).orElseThrow();

            assertThat(found.hasDetail()).isTrue();
            assertThat(found.getDifficulty()).isEqualTo(QuizDifficulty.HARD);
            assertThat(found.getOneLineAnswer()).isEqualTo("스택은 [[LIFO]]입니다.");
            assertThat(found.getBlocks())
                    .extracting(QuizFollowUpBlock::getLabel)
                    .containsExactly("해설", "실무 사용처");
            assertThat(found.getKeywords())
                    .extracting(QuizFollowUpKeyword::getKeyword)
                    .containsExactly("LIFO");
        }

        @Test
        @DisplayName("상세를 붙이지 않은 꼬리질문은 난이도와 한 줄 답이 비어 있다 — 백필 전의 실제 상태")
        void allows_follow_up_question_without_detail() {
            Quiz quiz = quizRepository.saveAndFlush(QuizFixture.oxQuiz());
            entityManager.clear();

            QuizFollowUpQuestion found = quizRepository
                    .findById(quiz.getId())
                    .orElseThrow()
                    .getFollowUpQuestions()
                    .get(0);

            assertThat(found.hasDetail()).isFalse();
            assertThat(found.getDifficulty()).isNull();
            assertThat(found.getBlocks()).isEmpty();
        }

        @Test
        @DisplayName("난이도 없이 한 줄 답만 채우면 DB 제약이 막는다 — 생성 파이프라인(#26)의 raw SQL 백필 대비")
        void rejects_detail_with_only_one_line_answer() {
            Quiz quiz = quizRepository.saveAndFlush(QuizFixture.oxQuiz());
            Long followUpQuestionId = quiz.getFollowUpQuestions().get(0).getId();

            assertThatThrownBy(() -> {
                        entityManager
                                .createNativeQuery(
                                        "UPDATE quiz_follow_up_question SET one_line_answer = '한 줄 답' WHERE id = ?1")
                                .setParameter(1, followUpQuestionId)
                                .executeUpdate();
                        entityManager.flush();
                    })
                    .isInstanceOf(PersistenceException.class);
        }

        @Test
        @DisplayName("출처 문제가 지워지면 꼬리질문의 블록과 키워드까지 함께 지워진다")
        void cascades_delete_to_blocks_and_keywords() {
            Quiz quiz = persistQuizWithDetailedFollowUpQuestion();
            long blocksBefore = countRows("quiz_follow_up_block");
            long keywordsBefore = countRows("quiz_follow_up_keyword");

            quizRepository.delete(quiz);
            entityManager.flush();

            assertThat(countRows("quiz_follow_up_block")).isEqualTo(blocksBefore - 2);
            assertThat(countRows("quiz_follow_up_keyword")).isEqualTo(keywordsBefore - 1);
        }
    }

    @Nested
    @DisplayName("findWithQuizById")
    class FindWithQuizById {

        @Test
        @DisplayName("출처 문제를 함께 읽어온다 — 응답의 sourceQuizNumber가 부모의 slotOrder이기 때문")
        void fetches_source_quiz() {
            Long followUpQuestionId = persistAndDetach();

            QuizFollowUpQuestion found = quizFollowUpQuestionRepository
                    .findWithQuizById(followUpQuestionId)
                    .orElseThrow();

            assertThat(found.getQuiz().getQuestionText()).isEqualTo("TCP는 연결 지향 프로토콜이다.");
        }

        @Test
        @DisplayName("없는 ID면 빈 Optional을 반환한다")
        void returns_empty_when_absent() {
            assertThat(quizFollowUpQuestionRepository.findWithQuizById(999_999L))
                    .isEmpty();
        }
    }
}
