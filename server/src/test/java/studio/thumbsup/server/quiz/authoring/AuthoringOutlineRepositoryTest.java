package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import jakarta.persistence.EntityManager;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import studio.thumbsup.server.common.support.DatabaseCleanUp;
import studio.thumbsup.server.common.support.RepositoryTestSupport;

class AuthoringOutlineRepositoryTest extends RepositoryTestSupport {

    private final AuthoringOutlineRepository outlineRepository;
    private final AuthoringOutlineStepRepository stepRepository;
    private final DatabaseCleanUp databaseCleanUp;
    private final EntityManager entityManager;

    AuthoringOutlineRepositoryTest(
            @Autowired AuthoringOutlineRepository outlineRepository,
            @Autowired AuthoringOutlineStepRepository stepRepository,
            @Autowired DatabaseCleanUp databaseCleanUp,
            @Autowired EntityManager entityManager) {
        this.outlineRepository = outlineRepository;
        this.stepRepository = stepRepository;
        this.databaseCleanUp = databaseCleanUp;
        this.entityManager = entityManager;
    }

    @BeforeEach
    void cleanSeedData() {
        databaseCleanUp.execute();
    }

    @Nested
    @DisplayName("뼈대 스텝 저장은")
    class OutlineStepPersistence {

        @Test
        @DisplayName("같은 뼈대에 같은 order_no를 두 번 쓸 수 없다")
        void rejects_duplicate_order_no_within_outline() {
            AuthoringOutline outline =
                    outlineRepository.saveAndFlush(AuthoringOutline.create("운영체제", "CS 기초", "1장 ...", 1L));
            stepRepository.saveAndFlush(AuthoringOutlineStep.create(outline.getId(), 1, "프로세스", "목표"));

            assertThatThrownBy(() ->
                            stepRepository.saveAndFlush(AuthoringOutlineStep.create(outline.getId(), 1, "스레드", "목표")))
                    .isInstanceOf(DataIntegrityViolationException.class);
        }

        @Test
        @DisplayName("다른 뼈대끼리는 같은 order_no를 쓸 수 있다")
        void allows_same_order_no_across_outlines() {
            AuthoringOutline first = outlineRepository.save(AuthoringOutline.create("첫 코스", "카테고리", "목차", 1L));
            AuthoringOutline second = outlineRepository.save(AuthoringOutline.create("둘째 코스", "카테고리", "목차", 1L));

            stepRepository.saveAndFlush(AuthoringOutlineStep.create(first.getId(), 1, "첫 스텝", "목표"));
            stepRepository.saveAndFlush(AuthoringOutlineStep.create(second.getId(), 1, "둘째 스텝", "목표"));

            assertThat(stepRepository.findByOutlineIdOrderByOrderNoAsc(first.getId()))
                    .hasSize(1);
            assertThat(stepRepository.findByOutlineIdOrderByOrderNoAsc(second.getId()))
                    .hasSize(1);
        }

        @Test
        @DisplayName("draft가 붙은 스텝이 하나라도 있으면 existsBy...DraftIdIsNotNull이 true다")
        void detects_filled_steps() {
            AuthoringOutline outline =
                    outlineRepository.saveAndFlush(AuthoringOutline.create("운영체제", "CS 기초", "목차", 1L));
            stepRepository.save(AuthoringOutlineStep.create(outline.getId(), 1, "비어 있음", "목표"));
            AuthoringOutlineStep filled = AuthoringOutlineStep.create(outline.getId(), 2, "채워짐", "목표");
            filled.attachDraft(99L);
            stepRepository.saveAndFlush(filled);

            assertThat(stepRepository.existsByOutlineIdAndDraftIdIsNotNull(outline.getId()))
                    .isTrue();
        }

        @Test
        @DisplayName("스텝은 order_no 오름차순으로 조회된다")
        void lists_steps_in_order() {
            AuthoringOutline outline =
                    outlineRepository.saveAndFlush(AuthoringOutline.create("운영체제", "CS 기초", "목차", 1L));
            stepRepository.saveAllAndFlush(List.of(
                    AuthoringOutlineStep.create(outline.getId(), 3, "세 번째", "목표"),
                    AuthoringOutlineStep.create(outline.getId(), 1, "첫 번째", "목표"),
                    AuthoringOutlineStep.create(outline.getId(), 2, "두 번째", "목표")));

            assertThat(stepRepository.findByOutlineIdOrderByOrderNoAsc(outline.getId()))
                    .extracting(AuthoringOutlineStep::getOrderNo)
                    .containsExactly(1, 2, 3);
        }
    }
}
