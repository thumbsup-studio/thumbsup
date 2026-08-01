package studio.thumbsup.server.quiz.concept;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.DatabaseCleanUp;
import studio.thumbsup.server.common.config.ClockConfig;
import studio.thumbsup.server.common.config.JpaAuditingConfig;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizFixture;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;

/**
 * Repository 통합 테스트 — 실제 MySQL(Testcontainers)에 Flyway 마이그레이션을 적용해
 * concept/concept_relation/user_concept/user_concept_step 저장·조회·제약을 검증한다(#233).
 * Flyway 시드(개념 마스터 64개)와 겹치지 않도록 매 테스트 전 테이블을 비운다 — step_order가
 * quiz_step을 FK로 참조하므로 스텝이 필요한 픽스처는 코스·스텝 부모 행을 먼저 만든다.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@Import({ClockConfig.class, JpaAuditingConfig.class, DatabaseCleanUp.class})
@ActiveProfiles("test")
@DisplayName("개념 리포지토리")
class ConceptRepositoryTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final ConceptRepository conceptRepository;
    private final ConceptDescriptionRepository conceptDescriptionRepository;
    private final ConceptRelationRepository conceptRelationRepository;
    private final QuizConceptRepository quizConceptRepository;
    private final UserConceptRepository userConceptRepository;
    private final UserConceptStepRepository userConceptStepRepository;
    private final DatabaseCleanUp databaseCleanUp;

    // QuizConcept 픽스처(saveStep/saveQuiz)만 쓰는 주변부 의존성 — 생성자에 추가하면 체크스타일
    // 파라미터 수 상한(7개)을 넘긴다.
    @Autowired
    private QuizRepository quizRepository;

    @Autowired
    private QuizStepRepository quizStepRepository;

    @Autowired
    private CourseRepository courseRepository;

    ConceptRepositoryTest(
            @Autowired ConceptRepository conceptRepository,
            @Autowired ConceptDescriptionRepository conceptDescriptionRepository,
            @Autowired ConceptRelationRepository conceptRelationRepository,
            @Autowired QuizConceptRepository quizConceptRepository,
            @Autowired UserConceptRepository userConceptRepository,
            @Autowired UserConceptStepRepository userConceptStepRepository,
            @Autowired DatabaseCleanUp databaseCleanUp) {
        this.conceptRepository = conceptRepository;
        this.conceptDescriptionRepository = conceptDescriptionRepository;
        this.conceptRelationRepository = conceptRelationRepository;
        this.quizConceptRepository = quizConceptRepository;
        this.userConceptRepository = userConceptRepository;
        this.userConceptStepRepository = userConceptStepRepository;
        this.databaseCleanUp = databaseCleanUp;
    }

    @BeforeEach
    void cleanUp() {
        databaseCleanUp.execute();
    }

    private Concept saveConcept(String name) {
        return conceptRepository.saveAndFlush(ConceptFixture.concept(null, name, "테스트 카테고리"));
    }

    /** step_order가 quiz_step(→course)을 FK로 참조하므로, 스텝이 필요한 픽스처 전에 부모 행을 만든다. */
    private void saveStep(int stepOrder) {
        Long courseId = courseRepository
                .save(Course.create("테스트 코스 " + stepOrder, "CS"))
                .getId();
        quizStepRepository.save(QuizStep.create(stepOrder, courseId, "테스트 스텝 " + stepOrder, 5));
    }

    private Quiz saveQuiz(int stepOrder, int slotOrder) {
        Quiz quiz = QuizFixture.oxQuiz();
        quiz.assignPosition(stepOrder, slotOrder);
        return quizRepository.save(quiz);
    }

    @Nested
    @DisplayName("Concept")
    class ConceptTests {

        @Test
        @DisplayName("같은 name을 두 번 저장하면 유니크 제약 위반이다")
        void rejects_duplicate_name() {
            saveConcept("뮤텍스");

            org.junit.jupiter.api.Assertions.assertThrows(
                    DataIntegrityViolationException.class, () -> saveConcept("뮤텍스"));
        }
    }

    @Nested
    @DisplayName("ConceptDescription")
    class ConceptDescriptionTests {

        @Test
        @DisplayName("같은 개념·스텝 조합은 유니크하다")
        void rejects_duplicate_concept_step() {
            saveStep(2);
            Concept concept = saveConcept("문맥 전환");
            conceptDescriptionRepository.saveAndFlush(
                    ConceptFixture.conceptDescription(concept.getId(), "PCB에 상태를 저장·복원하는 작업이다.", 2));

            org.junit.jupiter.api.Assertions.assertThrows(
                    DataIntegrityViolationException.class,
                    () -> conceptDescriptionRepository.saveAndFlush(
                            ConceptFixture.conceptDescription(concept.getId(), "다른 문장", 2)));
        }

        @Test
        @DisplayName("존재하지 않는 스텝을 가리키는 설명은 FK 위반으로 저장할 수 없다")
        void rejects_description_with_unknown_step_order() {
            Concept concept = saveConcept("문맥 전환");

            org.junit.jupiter.api.Assertions.assertThrows(
                    DataIntegrityViolationException.class,
                    () -> conceptDescriptionRepository.saveAndFlush(
                            ConceptFixture.conceptDescription(concept.getId(), "고아 설명 문장", 99)));
        }

        @Test
        @DisplayName("한 개념이 여러 스텝에 걸친 설명을 가지면 전부 조회된다")
        void finds_all_descriptions_for_concept() {
            saveStep(2);
            saveStep(4);
            Concept concept = saveConcept("문맥 전환");
            conceptDescriptionRepository.save(
                    ConceptFixture.conceptDescription(concept.getId(), "PCB에 상태를 저장·복원하는 작업이다.", 2));
            conceptDescriptionRepository.save(
                    ConceptFixture.conceptDescription(concept.getId(), "타임 퀀텀이 작으면 오버헤드가 된다.", 4));

            List<ConceptDescription> found = conceptDescriptionRepository.findByConceptIdIn(Set.of(concept.getId()));

            assertThat(found).extracting(ConceptDescription::getStepOrder).containsExactlyInAnyOrder(2, 4);
        }
    }

    @Nested
    @DisplayName("QuizConcept")
    class QuizConceptTests {

        @Test
        @DisplayName("퀴즈당 핵심 개념은 하나만 연결할 수 있다(UNIQUE(quiz_id))")
        void rejects_second_concept_for_same_quiz() {
            saveStep(101);
            Quiz quiz = saveQuiz(101, 1);
            Concept a = saveConcept("뮤텍스");
            Concept b = saveConcept("세마포어");
            quizConceptRepository.saveAndFlush(ConceptFixture.quizConcept(quiz.getId(), a.getId()));

            org.junit.jupiter.api.Assertions.assertThrows(
                    DataIntegrityViolationException.class,
                    () -> quizConceptRepository.saveAndFlush(ConceptFixture.quizConcept(quiz.getId(), b.getId())));
        }

        @Test
        @DisplayName("여러 퀴즈에 걸친 개념 id를 중복 없이 조회한다(스텝 완료 시 학습 기록용)")
        void finds_distinct_concept_ids_across_quizzes() {
            saveStep(101);
            Quiz first = saveQuiz(101, 1);
            Quiz second = saveQuiz(101, 2);
            Quiz third = saveQuiz(101, 3);
            Concept concept = saveConcept("뮤텍스");
            quizConceptRepository.save(ConceptFixture.quizConcept(first.getId(), concept.getId()));
            quizConceptRepository.save(ConceptFixture.quizConcept(second.getId(), concept.getId()));

            List<Long> found = quizConceptRepository.findDistinctConceptIdsByQuizIdIn(
                    List.of(first.getId(), second.getId(), third.getId()));

            assertThat(found).containsExactly(concept.getId());
        }
    }

    @Nested
    @DisplayName("ConceptRelation")
    class ConceptRelationTests {

        @Test
        @DisplayName("양쪽 concept id가 모두 조회 집합에 있는 관계만 반환한다")
        void finds_relations_within_given_concept_ids() {
            Concept a = saveConcept("뮤텍스");
            Concept b = saveConcept("세마포어");
            Concept c = saveConcept("교착 상태");
            conceptRelationRepository.saveAndFlush(ConceptFixture.relation(a.getId(), b.getId()));
            conceptRelationRepository.saveAndFlush(ConceptFixture.relation(b.getId(), c.getId()));

            List<ConceptRelation> found = conceptRelationRepository.findBySourceConceptIdInAndTargetConceptIdIn(
                    Set.of(a.getId(), b.getId()), Set.of(a.getId(), b.getId()));

            assertThat(found).hasSize(1);
            assertThat(found.get(0).getSourceConceptId()).isEqualTo(a.getId());
            assertThat(found.get(0).getTargetConceptId()).isEqualTo(b.getId());
        }
    }

    @Nested
    @DisplayName("UserConcept")
    class UserConceptTests {

        @Test
        @DisplayName("유저·개념 조합은 유니크하다")
        void rejects_duplicate_user_concept_pair() {
            Concept concept = saveConcept("뮤텍스");
            userConceptRepository.saveAndFlush(UserConcept.create(1L, concept.getId()));

            org.junit.jupiter.api.Assertions.assertThrows(
                    DataIntegrityViolationException.class,
                    () -> userConceptRepository.saveAndFlush(UserConcept.create(1L, concept.getId())));
        }

        @Test
        @DisplayName("createdAt이 learnedAt 역할을 하도록 감사 필드가 자동으로 채워진다")
        void fills_created_at_on_save() {
            Concept concept = saveConcept("뮤텍스");

            UserConcept saved = userConceptRepository.save(UserConcept.create(1L, concept.getId()));

            assertThat(saved.getCreatedAt()).isNotNull();
        }

        @Test
        @DisplayName("유저 기준으로 학습한 모든 개념을 조회한다")
        void finds_by_user_id() {
            Concept a = saveConcept("뮤텍스");
            Concept b = saveConcept("세마포어");
            userConceptRepository.save(UserConcept.create(1L, a.getId()));
            userConceptRepository.save(UserConcept.create(1L, b.getId()));
            userConceptRepository.save(UserConcept.create(2L, a.getId())); // 다른 유저 — 섞이면 안 됨

            List<UserConcept> found = userConceptRepository.findByUserId(1L);

            assertThat(found).extracting(UserConcept::getConceptId).containsExactlyInAnyOrder(a.getId(), b.getId());
        }
    }

    @Nested
    @DisplayName("UserConceptStep")
    class UserConceptStepTests {

        @Test
        @DisplayName("같은 유저·개념·스텝 조합은 유니크하다")
        void rejects_duplicate_triple() {
            saveStep(3);
            Concept concept = saveConcept("뮤텍스");
            userConceptStepRepository.saveAndFlush(UserConceptStep.create(1L, concept.getId(), 3));

            org.junit.jupiter.api.Assertions.assertThrows(
                    DataIntegrityViolationException.class,
                    () -> userConceptStepRepository.saveAndFlush(UserConceptStep.create(1L, concept.getId(), 3)));
        }

        @Test
        @DisplayName("같은 개념이 여러 스텝에 걸쳐 있으면 전부 조회된다(relatedSteps 조립용)")
        void finds_all_related_steps_for_concept() {
            saveStep(3);
            saveStep(6);
            Concept concept = saveConcept("뮤텍스");
            userConceptStepRepository.save(UserConceptStep.create(1L, concept.getId(), 3));
            userConceptStepRepository.save(UserConceptStep.create(1L, concept.getId(), 6));

            List<UserConceptStep> found =
                    userConceptStepRepository.findByUserIdAndConceptIdIn(1L, Set.of(concept.getId()));

            assertThat(found).extracting(UserConceptStep::getStepOrder).containsExactlyInAnyOrder(3, 6);
        }
    }
}
