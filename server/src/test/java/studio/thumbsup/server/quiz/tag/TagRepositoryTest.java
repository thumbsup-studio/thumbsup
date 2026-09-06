package studio.thumbsup.server.quiz.tag;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import studio.thumbsup.server.common.support.DatabaseCleanUp;
import studio.thumbsup.server.common.support.RepositoryTestSupport;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizFixture;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;

/**
 * Repository 통합 테스트 — 실제 MySQL(Testcontainers)에 Flyway 마이그레이션을 적용해
 * tag/tag_relation/user_tag/user_tag_step 저장·조회·제약을 검증한다(#233, #324).
 * Flyway 시드(태그 마스터 64개)와 겹치지 않도록 매 테스트 전 테이블을 비운다 — quiz_step_id(#292)가
 * quiz_step을 FK로 참조하므로 스텝이 필요한 픽스처는 코스·스텝 부모 행을 먼저 만든다.
 */
@DisplayName("태그 리포지토리")
class TagRepositoryTest extends RepositoryTestSupport {

    private final TagRepository tagRepository;
    private final TagDescriptionRepository tagDescriptionRepository;
    private final TagRelationRepository tagRelationRepository;
    private final QuizTagRepository quizTagRepository;
    private final UserTagRepository userTagRepository;
    private final UserTagStepRepository userTagStepRepository;
    private final DatabaseCleanUp databaseCleanUp;

    // QuizTag 픽스처(saveStep/saveQuiz)만 쓰는 주변부 의존성 — 생성자에 추가하면 체크스타일
    // 파라미터 수 상한(7개)을 넘긴다.
    @Autowired
    private QuizRepository quizRepository;

    @Autowired
    private QuizStepRepository quizStepRepository;

    @Autowired
    private CourseRepository courseRepository;

    TagRepositoryTest(
            @Autowired TagRepository tagRepository,
            @Autowired TagDescriptionRepository tagDescriptionRepository,
            @Autowired TagRelationRepository tagRelationRepository,
            @Autowired QuizTagRepository quizTagRepository,
            @Autowired UserTagRepository userTagRepository,
            @Autowired UserTagStepRepository userTagStepRepository,
            @Autowired DatabaseCleanUp databaseCleanUp) {
        this.tagRepository = tagRepository;
        this.tagDescriptionRepository = tagDescriptionRepository;
        this.tagRelationRepository = tagRelationRepository;
        this.quizTagRepository = quizTagRepository;
        this.userTagRepository = userTagRepository;
        this.userTagStepRepository = userTagStepRepository;
        this.databaseCleanUp = databaseCleanUp;
    }

    @BeforeEach
    void cleanUp() {
        databaseCleanUp.execute();
    }

    private Tag saveTag(String name) {
        return tagRepository.saveAndFlush(TagFixture.tag(null, name, "테스트 카테고리"));
    }

    /** quiz_step_id가 quiz_step(→course)을 FK로 참조하므로(#292), 스텝이 필요한 픽스처 전에 부모 행을 만들고 PK를 반환한다. */
    private Long saveStep(int stepOrder) {
        Long courseId = courseRepository
                .save(Course.create("테스트 코스 " + stepOrder, "CS"))
                .getId();
        return quizStepRepository
                .save(QuizStep.create(stepOrder, courseId, "테스트 스텝 " + stepOrder, 5))
                .getId();
    }

    private Quiz saveQuiz(Long stepId, int stepOrder, int slotOrder) {
        Quiz quiz = QuizFixture.oxQuiz();
        quiz.assignPosition(stepId, stepOrder, slotOrder);
        return quizRepository.save(quiz);
    }

    @Nested
    @DisplayName("Tag")
    class TagTests {

        @Test
        @DisplayName("같은 name을 두 번 저장하면 유니크 제약 위반이다")
        void rejects_duplicate_name() {
            saveTag("뮤텍스");

            assertThatThrownBy(() -> saveTag("뮤텍스")).isInstanceOf(DataIntegrityViolationException.class);
        }

        @Test
        @DisplayName("대소문자·앞뒤 공백만 다른 이름은 정규화 유니크 제약 위반이다(#324)")
        void rejects_name_differing_only_by_case_or_whitespace() {
            saveTag("Mutex");

            assertThatThrownBy(() -> saveTag(" mutex ")).isInstanceOf(DataIntegrityViolationException.class);
        }
    }

    @Nested
    @DisplayName("TagDescription")
    class TagDescriptionTests {

        @Test
        @DisplayName("같은 태그·스텝 조합은 유니크하다")
        void rejects_duplicate_tag_step() {
            Long stepId = saveStep(2);
            Tag tag = saveTag("문맥 전환");
            tagDescriptionRepository.saveAndFlush(
                    TagFixture.tagDescription(tag.getId(), "PCB에 상태를 저장·복원하는 작업이다.", stepId));

            assertThatThrownBy(() -> tagDescriptionRepository.saveAndFlush(
                            TagFixture.tagDescription(tag.getId(), "다른 문장", stepId)))
                    .isInstanceOf(DataIntegrityViolationException.class);
        }

        @Test
        @DisplayName("존재하지 않는 스텝을 가리키는 설명은 FK 위반으로 저장할 수 없다")
        void rejects_description_with_unknown_step_order() {
            Tag tag = saveTag("문맥 전환");

            assertThatThrownBy(() -> tagDescriptionRepository.saveAndFlush(
                            TagFixture.tagDescription(tag.getId(), "고아 설명 문장", 999_999L)))
                    .isInstanceOf(DataIntegrityViolationException.class);
        }

        @Test
        @DisplayName("한 태그가 여러 스텝에 걸친 설명을 가지면 전부 조회된다")
        void finds_all_descriptions_for_tag() {
            Long stepTwoId = saveStep(2);
            Long stepFourId = saveStep(4);
            Tag tag = saveTag("문맥 전환");
            tagDescriptionRepository.save(TagFixture.tagDescription(tag.getId(), "PCB에 상태를 저장·복원하는 작업이다.", stepTwoId));
            tagDescriptionRepository.save(TagFixture.tagDescription(tag.getId(), "타임 퀀텀이 작으면 오버헤드가 된다.", stepFourId));

            List<TagDescription> found = tagDescriptionRepository.findByTagIdIn(Set.of(tag.getId()));

            assertThat(found)
                    .extracting(TagDescription::getQuizStepId)
                    .containsExactlyInAnyOrder(stepTwoId, stepFourId);
        }
    }

    @Nested
    @DisplayName("QuizTag")
    class QuizTagTests {

        @Test
        @DisplayName("같은 퀴즈에 태그를 최대 3개까지 연결할 수 있다(#324 카디널리티 확장)")
        void allows_up_to_three_tags_for_same_quiz() {
            Long stepId = saveStep(101);
            Quiz quiz = saveQuiz(stepId, 101, 1);
            Tag a = saveTag("뮤텍스");
            Tag b = saveTag("세마포어");
            Tag c = saveTag("교착 상태");

            quizTagRepository.saveAndFlush(TagFixture.quizTag(quiz.getId(), a.getId()));
            quizTagRepository.saveAndFlush(TagFixture.quizTag(quiz.getId(), b.getId()));
            quizTagRepository.saveAndFlush(TagFixture.quizTag(quiz.getId(), c.getId()));

            List<Long> found = quizTagRepository.findDistinctTagIdsByQuizIdIn(List.of(quiz.getId()));
            assertThat(found).containsExactlyInAnyOrder(a.getId(), b.getId(), c.getId());
        }

        @Test
        @DisplayName("같은 태그를 같은 퀴즈에 두 번 연결할 수 없다(UNIQUE(quiz_id, tag_id))")
        void rejects_duplicate_tag_for_same_quiz() {
            Long stepId = saveStep(101);
            Quiz quiz = saveQuiz(stepId, 101, 1);
            Tag tag = saveTag("뮤텍스");
            quizTagRepository.saveAndFlush(TagFixture.quizTag(quiz.getId(), tag.getId()));

            assertThatThrownBy(() -> quizTagRepository.saveAndFlush(TagFixture.quizTag(quiz.getId(), tag.getId())))
                    .isInstanceOf(DataIntegrityViolationException.class);
        }

        @Test
        @DisplayName("여러 퀴즈에 걸친 태그 id를 중복 없이 조회한다(스텝 완료 시 학습 기록용)")
        void finds_distinct_tag_ids_across_quizzes() {
            Long stepId = saveStep(101);
            Quiz first = saveQuiz(stepId, 101, 1);
            Quiz second = saveQuiz(stepId, 101, 2);
            Quiz third = saveQuiz(stepId, 101, 3);
            Tag tag = saveTag("뮤텍스");
            quizTagRepository.save(TagFixture.quizTag(first.getId(), tag.getId()));
            quizTagRepository.save(TagFixture.quizTag(second.getId(), tag.getId()));

            List<Long> found = quizTagRepository.findDistinctTagIdsByQuizIdIn(
                    List.of(first.getId(), second.getId(), third.getId()));

            assertThat(found).containsExactly(tag.getId());
        }
    }

    @Nested
    @DisplayName("TagRelation")
    class TagRelationTests {

        @Test
        @DisplayName("양쪽 태그 id가 모두 조회 집합에 있는 관계만 반환한다")
        void finds_relations_within_given_tag_ids() {
            Tag a = saveTag("뮤텍스");
            Tag b = saveTag("세마포어");
            Tag c = saveTag("교착 상태");
            tagRelationRepository.saveAndFlush(TagFixture.relation(a.getId(), b.getId()));
            tagRelationRepository.saveAndFlush(TagFixture.relation(b.getId(), c.getId()));

            List<TagRelation> found = tagRelationRepository.findBySourceTagIdInAndTargetTagIdIn(
                    Set.of(a.getId(), b.getId()), Set.of(a.getId(), b.getId()));

            assertThat(found).hasSize(1);
            assertThat(found.get(0).getSourceTagId()).isEqualTo(a.getId());
            assertThat(found.get(0).getTargetTagId()).isEqualTo(b.getId());
        }
    }

    @Nested
    @DisplayName("UserTag")
    class UserTagTests {

        @Test
        @DisplayName("유저·태그 조합은 유니크하다")
        void rejects_duplicate_user_tag_pair() {
            Tag tag = saveTag("뮤텍스");
            userTagRepository.saveAndFlush(UserTag.create(1L, tag.getId()));

            assertThatThrownBy(() -> userTagRepository.saveAndFlush(UserTag.create(1L, tag.getId())))
                    .isInstanceOf(DataIntegrityViolationException.class);
        }

        @Test
        @DisplayName("createdAt이 learnedAt 역할을 하도록 감사 필드가 자동으로 채워진다")
        void fills_created_at_on_save() {
            Tag tag = saveTag("뮤텍스");

            UserTag saved = userTagRepository.save(UserTag.create(1L, tag.getId()));

            assertThat(saved.getCreatedAt()).isNotNull();
        }

        @Test
        @DisplayName("유저 기준으로 학습한 모든 태그를 조회한다")
        void finds_by_user_id() {
            Tag a = saveTag("뮤텍스");
            Tag b = saveTag("세마포어");
            userTagRepository.save(UserTag.create(1L, a.getId()));
            userTagRepository.save(UserTag.create(1L, b.getId()));
            userTagRepository.save(UserTag.create(2L, a.getId())); // 다른 유저 — 섞이면 안 됨

            List<UserTag> found = userTagRepository.findByUserId(1L);

            assertThat(found).extracting(UserTag::getTagId).containsExactlyInAnyOrder(a.getId(), b.getId());
        }

        @Test
        @DisplayName("이미 학습한 유저·태그 조합에 upsert를 호출하면 아무 것도 바꾸지 않는다(#324 동시성 안전장치)")
        void upsert_does_not_duplicate_existing_pair() {
            Tag tag = saveTag("뮤텍스");
            userTagRepository.saveAndFlush(UserTag.create(1L, tag.getId()));

            userTagRepository.upsert(1L, tag.getId(), java.time.Instant.parse("2026-08-01T00:00:00Z"));

            List<UserTag> found = userTagRepository.findByUserId(1L);
            assertThat(found).hasSize(1);
        }

        @Test
        @DisplayName("아직 없는 유저·태그 조합에 upsert를 호출하면 새로 기록한다")
        void upsert_inserts_new_pair() {
            Tag tag = saveTag("뮤텍스");

            userTagRepository.upsert(1L, tag.getId(), java.time.Instant.parse("2026-08-01T00:00:00Z"));

            List<UserTag> found = userTagRepository.findByUserId(1L);
            assertThat(found).extracting(UserTag::getTagId).containsExactly(tag.getId());
        }
    }

    @Nested
    @DisplayName("UserTagStep")
    class UserTagStepTests {

        @Test
        @DisplayName("같은 유저·태그·스텝 조합은 유니크하다")
        void rejects_duplicate_triple() {
            Long stepId = saveStep(3);
            Tag tag = saveTag("뮤텍스");
            userTagStepRepository.saveAndFlush(UserTagStep.create(1L, tag.getId(), stepId));

            assertThatThrownBy(() -> userTagStepRepository.saveAndFlush(UserTagStep.create(1L, tag.getId(), stepId)))
                    .isInstanceOf(DataIntegrityViolationException.class);
        }

        @Test
        @DisplayName("같은 태그가 여러 스텝에 걸쳐 있으면 전부 조회된다(relatedSteps 조립용)")
        void finds_all_related_steps_for_tag() {
            Long stepThreeId = saveStep(3);
            Long stepSixId = saveStep(6);
            Tag tag = saveTag("뮤텍스");
            userTagStepRepository.save(UserTagStep.create(1L, tag.getId(), stepThreeId));
            userTagStepRepository.save(UserTagStep.create(1L, tag.getId(), stepSixId));

            List<UserTagStep> found = userTagStepRepository.findByUserIdAndTagIdIn(1L, Set.of(tag.getId()));

            assertThat(found).extracting(UserTagStep::getQuizStepId).containsExactlyInAnyOrder(stepThreeId, stepSixId);
        }
    }
}
