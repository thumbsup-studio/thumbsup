package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import studio.thumbsup.server.common.support.DatabaseCleanUp;
import studio.thumbsup.server.common.support.RepositoryTestSupport;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;

/** 브리핑 aggregate의 Flyway 스키마·FK·정렬 제약을 실제 MySQL에서 검증한다. */
class QuizStepBriefingRepositoryTest extends RepositoryTestSupport {

    private final QuizStepBriefingRepository briefingRepository;
    private final QuizStepRepository quizStepRepository;
    private final CourseRepository courseRepository;
    private final DatabaseCleanUp databaseCleanUp;
    private final EntityManager entityManager;

    private Long quizStepId;

    QuizStepBriefingRepositoryTest(
            @Autowired QuizStepBriefingRepository briefingRepository,
            @Autowired QuizStepRepository quizStepRepository,
            @Autowired CourseRepository courseRepository,
            @Autowired DatabaseCleanUp databaseCleanUp,
            @Autowired EntityManager entityManager) {
        this.briefingRepository = briefingRepository;
        this.quizStepRepository = quizStepRepository;
        this.courseRepository = courseRepository;
        this.databaseCleanUp = databaseCleanUp;
        this.entityManager = entityManager;
    }

    @BeforeEach
    void setUp() {
        databaseCleanUp.execute();
        Long courseId = courseRepository.save(Course.create("운영체제", "CS")).getId();
        quizStepId =
                quizStepRepository.save(QuizStep.create(1, courseId, "프로세스", 3)).getId();
    }

    @Nested
    @DisplayName("스텝 브리핑 저장")
    class PersistBriefing {

        @Test
        @DisplayName("블록을 displayOrder 순서로 조회한다")
        void returns_blocks_in_display_order() {
            QuizStepBriefing briefing = QuizStepBriefing.create(quizStepId, "프로세스의 실행 흐름을 살펴봅니다.");
            briefing.addBlock(QuizStepBriefingBlockType.EXAMPLE, "예시", "실행 중인 프로그램입니다.", 2);
            briefing.addBlock(QuizStepBriefingBlockType.CONCEPT, "핵심", "프로세스는 자원을 가진 실행 단위입니다.", 1);
            briefingRepository.saveAndFlush(briefing);
            entityManager.clear();

            QuizStepBriefing found =
                    briefingRepository.findWithBlocksByQuizStepId(quizStepId).orElseThrow();

            assertThat(found.getSummary()).isEqualTo("프로세스의 실행 흐름을 살펴봅니다.");
            assertThat(found.getBlocks())
                    .extracting(QuizStepBriefingBlock::getDisplayOrder)
                    .containsExactly(1, 2);
        }

        @Test
        @DisplayName("하나의 스텝에는 브리핑을 하나만 저장할 수 있다")
        void rejects_duplicate_briefing_for_step() {
            briefingRepository.saveAndFlush(QuizStepBriefing.create(quizStepId, "첫 브리핑"));

            assertThatThrownBy(() -> briefingRepository.saveAndFlush(QuizStepBriefing.create(quizStepId, "두 번째 브리핑")))
                    .isInstanceOf(DataIntegrityViolationException.class);
        }

        @Test
        @DisplayName("같은 브리핑 안에서 블록 순서는 중복될 수 없다")
        void rejects_duplicate_block_display_order() {
            QuizStepBriefing briefing = QuizStepBriefing.create(quizStepId, "중복 순서 검증");
            briefing.addBlock(QuizStepBriefingBlockType.CONCEPT, "첫 블록", "첫 내용", 1);
            briefing.addBlock(QuizStepBriefingBlockType.EXAMPLE, "둘째 블록", "둘째 내용", 1);

            assertThatThrownBy(() -> briefingRepository.saveAndFlush(briefing))
                    .isInstanceOf(DataIntegrityViolationException.class);
        }
    }

    @Nested
    @DisplayName("스텝 삭제")
    class DeleteStep {

        @Test
        @DisplayName("스텝을 삭제하면 연결된 브리핑과 블록도 함께 삭제된다")
        void deletes_briefing_with_step() {
            QuizStepBriefing briefing = QuizStepBriefing.create(quizStepId, "삭제 전 브리핑");
            briefing.addBlock(QuizStepBriefingBlockType.CONCEPT, "핵심", "내용", 1);
            briefingRepository.saveAndFlush(briefing);

            quizStepRepository.deleteById(quizStepId);
            quizStepRepository.flush();
            entityManager.clear();

            assertThat(briefingRepository.findWithBlocksByQuizStepId(quizStepId))
                    .isEmpty();
        }
    }
}
