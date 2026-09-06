package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceException;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import studio.thumbsup.server.common.support.RepositoryTestSupport;

/**
 * Repository 통합 테스트 — 실제 MySQL(Testcontainers)에 Flyway 마이그레이션을 적용해
 * 문제 유형별 자식 데이터 저장·조립을 검증한다 (피라미드 3층).
 */
class QuizRepositoryTest extends RepositoryTestSupport {

    private final QuizRepository quizRepository;
    private final QuizAttemptRepository quizAttemptRepository;
    private final QuizProgressRepository quizProgressRepository;
    private final QuizStepRepository quizStepRepository;
    private final EntityManager entityManager;

    QuizRepositoryTest(
            @Autowired QuizRepository quizRepository,
            @Autowired QuizAttemptRepository quizAttemptRepository,
            @Autowired QuizProgressRepository quizProgressRepository,
            @Autowired QuizStepRepository quizStepRepository,
            @Autowired EntityManager entityManager) {
        this.quizRepository = quizRepository;
        this.quizAttemptRepository = quizAttemptRepository;
        this.quizProgressRepository = quizProgressRepository;
        this.quizStepRepository = quizStepRepository;
        this.entityManager = entityManager;
    }

    private long countChoicesByQuizId(Long quizId) {
        return ((Number) entityManager
                        .createNativeQuery("SELECT COUNT(*) FROM quiz_choice WHERE quiz_id = :quizId")
                        .setParameter("quizId", quizId)
                        .getSingleResult())
                .longValue();
    }

    /** quiz.quiz_step_id가 quiz_step을 FK로 참조하므로(#292), 스텝에 문제를 저장하기 전 부모 행을 먼저 만든다. */
    private Long saveStep(int stepOrder) {
        return quizStepRepository
                .save(QuizStep.create(stepOrder, 1L, "테스트 스텝 " + stepOrder, 3))
                .getId();
    }

    @Nested
    @DisplayName("OX 문제 저장")
    class SaveOxQuiz {

        @Test
        @DisplayName("정답과 자식 데이터(꼬리질문·파생개념·키워드)가 함께 저장된다")
        void saves_with_children() {
            Long stepId = saveStep(101);
            Quiz quiz = QuizFixture.oxQuiz();
            quiz.assignPosition(stepId, 101, 1);
            Quiz saved = quizRepository.save(quiz);

            Quiz found = quizRepository.findById(saved.getId()).orElseThrow();
            assertThat(found.getType()).isEqualTo(QuizType.OX);
            assertThat(found.getCorrectAnswer()).isEqualTo("O");
            assertThat(found.getFollowUpQuestions()).hasSize(1);
            assertThat(found.getDerivedTags()).hasSize(1);
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
            Long stepId = saveStep(101);
            Quiz quiz = QuizFixture.multipleChoiceQuiz();
            quiz.assignPosition(stepId, 101, 1);
            Quiz saved = quizRepository.save(quiz);

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
            Long stepId = saveStep(101);
            Quiz quiz = QuizFixture.keywordBlankQuiz();
            quiz.assignPosition(stepId, 101, 1);
            Quiz saved = quizRepository.save(quiz);

            Quiz found = quizRepository.findById(saved.getId()).orElseThrow();
            assertThat(found.getAnswerKeywords()).hasSize(1);
            assertThat(found.getAnswerKeywords().get(0).getKeyword()).isEqualTo("LIFO");
        }
    }

    @Nested
    @DisplayName("감사 필드")
    class AuditFields {

        @Test
        @DisplayName("저장 시 자동으로 채워진다")
        void audit_fields_are_populated_on_save() {
            Long stepId = saveStep(101);
            Quiz quiz = QuizFixture.oxQuiz();
            quiz.assignPosition(stepId, 101, 1);
            Quiz saved = quizRepository.save(quiz);

            assertThat(saved.getCreatedAt()).isNotNull();
            assertThat(saved.getUpdatedAt()).isNotNull();
        }
    }

    @Nested
    @DisplayName("퀴즈 삭제")
    class DeleteQuiz {

        @Test
        @DisplayName("자식 데이터(선택지)도 DB에서 함께 삭제된다(cascade)")
        void deleting_quiz_cascades_to_children() {
            Long stepId = saveStep(101);
            Quiz quiz = QuizFixture.multipleChoiceQuiz();
            quiz.assignPosition(stepId, 101, 1);
            Quiz saved = quizRepository.save(quiz);
            Long id = saved.getId();
            assertThat(countChoicesByQuizId(id)).isEqualTo(4);

            quizRepository.delete(saved);
            quizRepository.flush();

            assertThat(quizRepository.findById(id)).isEmpty();
            assertThat(countChoicesByQuizId(id)).isZero();
        }
    }

    @Nested
    @DisplayName("스텝 단위 조회")
    class FindByStep {

        @Test
        @DisplayName("한 스텝의 5문제를 slot_order 순서대로 조회한다")
        void finds_step_quizzes_in_slot_order() {
            Long stepId = saveStep(101);
            List<Quiz> step = QuizFixture.step(stepId, 101);
            step.forEach(quizRepository::save);

            List<Quiz> found = quizRepository.findByQuizStepIdOrderBySlotOrderAsc(stepId);

            assertThat(found).hasSize(5);
            assertThat(found).extracting(Quiz::getSlotOrder).containsExactly(1, 2, 3, 4, 5);
        }

        @Test
        @DisplayName("스텝 완료 판정용으로 ID만 조회할 수 있다")
        void finds_step_quiz_ids() {
            Long stepId = saveStep(101);
            List<Quiz> step = QuizFixture.step(stepId, 101);
            List<Long> savedIds =
                    step.stream().map(quizRepository::save).map(Quiz::getId).toList();

            List<Long> foundIds = quizRepository.findIdsByQuizStepId(stepId);

            assertThat(foundIds).containsExactlyInAnyOrderElementsOf(savedIds);
        }

        @Test
        @DisplayName("스텝에 실제 저장된 문제 수를 조회한다")
        void counts_step_quizzes() {
            Long stepId = saveStep(101);
            QuizFixture.step(stepId, 101).forEach(quizRepository::save);

            assertThat(quizRepository.countByQuizStepId(stepId)).isEqualTo(5);
        }

        @Test
        @DisplayName("스텝·슬롯을 지정해 문제 1개를 조회한다(#151 재풀이용)")
        void finds_quiz_by_step_and_slot() {
            Long stepId = saveStep(101);
            QuizFixture.step(stepId, 101).forEach(quizRepository::save);

            Optional<Quiz> found = quizRepository.findByQuizStepIdAndSlotOrder(stepId, 3);

            assertThat(found).isPresent();
            assertThat(found.get().getSlotOrder()).isEqualTo(3);
        }

        @Test
        @DisplayName("존재하지 않는 스텝·슬롯 조합이면 빈 값을 반환한다")
        void returns_empty_when_step_slot_missing() {
            Long stepId = saveStep(101);
            QuizFixture.step(stepId, 101).forEach(quizRepository::save);

            assertThat(quizRepository.findByQuizStepIdAndSlotOrder(stepId, 9)).isEmpty();
        }
    }

    @Nested
    @DisplayName("퀴즈 풀이 이력")
    class QuizAttemptPersistence {

        @Test
        @DisplayName("같은 유저·퀴즈 조합도 복습을 위해 여러 번 저장할 수 있다")
        void allows_multiple_attempts_for_same_user_and_quiz() {
            Long stepId = saveStep(101);
            Quiz quizFixture = QuizFixture.oxQuiz();
            quizFixture.assignPosition(stepId, 101, 1);
            Quiz quiz = quizRepository.save(quizFixture);
            quizAttemptRepository.saveAndFlush(QuizAttempt.create(quiz, 1L, false));

            assertThatCode(() -> quizAttemptRepository.saveAndFlush(QuizAttempt.create(quiz, 1L, true)))
                    .doesNotThrowAnyException();
            assertThat(quizAttemptRepository.findAll()).hasSize(2);
        }

        @Test
        @DisplayName("풀이 이력이 남은 퀴즈는 삭제할 수 없다(ON DELETE RESTRICT)")
        void rejects_deleting_quiz_with_attempt_history() {
            Long stepId = saveStep(101);
            Quiz quizFixture = QuizFixture.oxQuiz();
            quizFixture.assignPosition(stepId, 101, 1);
            Quiz quiz = quizRepository.save(quizFixture);
            quizAttemptRepository.saveAndFlush(QuizAttempt.create(quiz, 1L, true));

            // 네이티브 SQL로 직접 삭제해 DB 제약(ON DELETE RESTRICT) 자체를 검증한다 —
            // quizRepository.delete()는 Hibernate가 플러시 시점에 quiz_attempt의 참조를
            // 미리 감지해 TransientObjectException을 던지므로 DB 레벨 확인에 부적합하다.
            assertThatThrownBy(() -> entityManager
                            .createNativeQuery("DELETE FROM quiz WHERE id = :id")
                            .setParameter("id", quiz.getId())
                            .executeUpdate())
                    .isInstanceOf(PersistenceException.class);
        }

        @Test
        @DisplayName("스텝 기준으로 유저의 풀이 이력을 조회한다")
        void finds_attempts_by_user_and_step() {
            Long stepId = saveStep(101);
            List<Quiz> step = QuizFixture.step(stepId, 101).stream()
                    .map(quizRepository::save)
                    .toList();
            quizAttemptRepository.save(QuizAttempt.create(step.get(0), 1L, true));

            List<QuizAttempt> attempts = quizAttemptRepository.findByUserIdAndQuiz_QuizStepId(1L, stepId);

            assertThat(attempts).hasSize(1);
            assertThat(attempts.get(0).getQuiz().getId()).isEqualTo(step.get(0).getId());
        }
    }

    @Nested
    @DisplayName("유저 진행 상태")
    class QuizProgressPersistence {

        @Test
        @DisplayName("생성 시 1스텝부터 시작하고, 진행하면 다음 스텝으로 넘어간다")
        void starts_at_step_one_and_advances() {
            QuizProgress progress = quizProgressRepository.save(QuizProgress.create(1L, 1L, 1));
            assertThat(progress.getCurrentStepOrder()).isEqualTo(1);

            progress.advanceToNextStep();
            quizProgressRepository.saveAndFlush(progress);

            QuizProgress found =
                    quizProgressRepository.findByUserIdAndCourseId(1L, 1L).orElseThrow();
            assertThat(found.getCurrentStepOrder()).isEqualTo(2);
        }
    }

    @Nested
    @DisplayName("스텝 주제(QuizStep)")
    class QuizStepPersistence {

        @Test
        @DisplayName("스텝 주제를 저장하고 조회한다")
        void saves_and_finds_by_step_order() {
            quizStepRepository.save(QuizStep.create(101, 1L, "CPU 스케줄링 기초", 5));

            QuizStep found =
                    quizStepRepository.findByCourseIdAndStepOrder(1L, 101).orElseThrow();

            assertThat(found.getTopic()).isEqualTo("CPU 스케줄링 기초");
            assertThat(found.getEstimatedMinutes()).isEqualTo(5);
        }

        @Test
        @DisplayName("존재하지 않는 quiz_step_id로 문제를 저장하면 FK 위반으로 실패한다")
        void rejects_quiz_with_unknown_quiz_step_id() {
            Quiz quiz = QuizFixture.oxQuiz();
            quiz.assignPosition(999_999L, 99, 1); // quiz_step에 없는 PK

            // Repository 프록시를 거치면 DataIntegrityViolationException으로 변환된다(PersistenceException 아님) —
            // 원본 예외를 그대로 보고 싶으면 entityManager 네이티브 쿼리를 써야 한다(다른 테스트 참고).
            assertThatThrownBy(() -> quizRepository.saveAndFlush(quiz))
                    .isInstanceOf(DataIntegrityViolationException.class);
        }

        @Test
        @DisplayName("범위 내 스텝을 스텝번호 오름차순으로 조회한다")
        void finds_steps_between_range_in_order() {
            quizStepRepository.save(QuizStep.create(103, 1L, "셋째", 5));
            quizStepRepository.save(QuizStep.create(101, 1L, "첫째", 5));
            quizStepRepository.save(QuizStep.create(102, 1L, "둘째", 5));

            List<QuizStep> found =
                    quizStepRepository.findByCourseIdAndStepOrderBetweenOrderByStepOrderAsc(1L, 101, 102);

            assertThat(found).extracting(QuizStep::getTopic).containsExactly("첫째", "둘째");
        }

        @Test
        @DisplayName("시작값이 끝값보다 크면 빈 목록을 반환한다")
        void returns_empty_when_start_greater_than_end() {
            quizStepRepository.save(QuizStep.create(101, 1L, "첫째", 5));

            List<QuizStep> found =
                    quizStepRepository.findByCourseIdAndStepOrderBetweenOrderByStepOrderAsc(1L, 101, 100);

            assertThat(found).isEmpty();
        }
    }

    @Nested
    @DisplayName("잠금 조회")
    class LockingFinder {

        @Test
        @DisplayName("findByIdForUpdate는 PESSIMISTIC_WRITE로 잠그고 동일한 quiz를 반환한다(#174 I2)")
        void locks_and_returns_the_quiz() {
            Long stepId = saveStep(101);
            Quiz quizFixture = QuizFixture.oxQuiz();
            quizFixture.assignPosition(stepId, 101, 1);
            Quiz saved = quizRepository.save(quizFixture);

            Quiz found = quizRepository.findByIdForUpdate(saved.getId()).orElseThrow();

            assertThat(found.getId()).isEqualTo(saved.getId());
        }
    }
}
