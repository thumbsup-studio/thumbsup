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

    /** 정식 커리큘럼(step_order >= 1)의 꼬리질문만 센다 — step_order 0은 샘플 문제다. */
    private long countCurriculumFollowUpQuestions(String extraCondition) {
        return countRows(
                "quiz_follow_up_question f JOIN quiz q ON f.quiz_id = q.id WHERE q.step_order > 0 " + extraCondition);
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
        @DisplayName("같은 꼬리질문에 같은 표시 순서의 블록을 또 넣으면 DB 제약이 막는다 — 백필 재적용 방지")
        void rejects_duplicate_block_display_order() {
            Long followUpQuestionId = persistAndDetach();

            assertThatThrownBy(() -> {
                        entityManager
                                .createNativeQuery("""
                                        INSERT INTO quiz_follow_up_block
                                            (follow_up_question_id, label, type, content, display_order)
                                        VALUES (?1, '해설', 'TEXT', '같은 칸을 또 넣는다.', 1)""")
                                .setParameter(1, followUpQuestionId)
                                .executeUpdate();
                        entityManager.flush();
                    })
                    .isInstanceOf(PersistenceException.class);
        }

        @Test
        @DisplayName("같은 꼬리질문 사전에 같은 용어를 또 넣으면 DB 제약이 막는다 — 툴팁에 같은 항목이 두 번 나오지 않는다")
        void rejects_duplicate_keyword_in_one_dictionary() {
            Long followUpQuestionId = persistAndDetach();

            assertThatThrownBy(() -> {
                        entityManager
                                .createNativeQuery("""
                                        INSERT INTO quiz_follow_up_keyword (follow_up_question_id, keyword, description)
                                        VALUES (?1, 'LIFO', '같은 용어를 또 넣는다.')""")
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
    @DisplayName("커리큘럼 백필(#133)")
    class CurriculumBackfill {

        /** 백필 시점의 커리큘럼 규모. 스텝이 늘면 커지므로 하한으로만 쓴다. */
        private static final long BACKFILLED_FOLLOW_UP_QUESTION_COUNT = 120L;

        @Test
        @DisplayName("커리큘럼 꼬리질문에 상세가 빠짐없이 채워져 있다 — 하나라도 비면 그 꼬리질문이 해설 화면에서 사라진다")
        void every_curriculum_follow_up_question_has_detail() {
            assertThat(countCurriculumFollowUpQuestions(""))
                    .isGreaterThanOrEqualTo(BACKFILLED_FOLLOW_UP_QUESTION_COUNT);
            assertThat(countCurriculumFollowUpQuestions("AND f.one_line_answer IS NULL"))
                    .isZero();
        }

        @Test
        @DisplayName("난이도와 한 줄 답이 한쪽만 채워진 행이 하나도 없다")
        void detail_columns_are_always_filled_in_pairs() {
            assertThat(countRows("quiz_follow_up_question WHERE (difficulty IS NULL) <> (one_line_answer IS NULL)"))
                    .isZero();
        }

        @Test
        @DisplayName("같은 꼬리질문에 같은 칸의 블록이나 같은 용어가 두 번 실려 있지 않다 — 백필이 두 번 적용되면 이렇게 된다")
        void detail_rows_are_never_duplicated() {
            assertThat(countRows("""
                            (SELECT 1 FROM quiz_follow_up_block
                             GROUP BY follow_up_question_id, display_order HAVING COUNT(*) > 1) AS duplicated_blocks""")).isZero();
            assertThat(countRows("""
                            (SELECT 1 FROM quiz_follow_up_keyword
                             GROUP BY follow_up_question_id, keyword HAVING COUNT(*) > 1) AS duplicated_keywords""")).isZero();
        }

        @Test
        @DisplayName("커리큘럼 꼬리질문은 모두 첫 블록이 \"해설\"이고 키워드 사전을 갖는다")
        void every_curriculum_follow_up_question_has_blocks_and_keywords() {
            assertThat(countCurriculumFollowUpQuestions("""
                            AND NOT EXISTS (SELECT 1 FROM quiz_follow_up_block b
                                            WHERE b.follow_up_question_id = f.id
                                              AND b.display_order = 1 AND b.label = '해설')""")).isZero();
            assertThat(countCurriculumFollowUpQuestions("""
                            AND NOT EXISTS (SELECT 1 FROM quiz_follow_up_keyword k
                                            WHERE k.follow_up_question_id = f.id)""")).isZero();
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
