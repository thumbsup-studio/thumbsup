package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.DatabaseCleanUp;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizFixture;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;
import studio.thumbsup.server.quiz.generation.QuizPreset;

/**
 * 승인(materialize) 통합 테스트 — 핵심 리스크인 IMPROVE의 in-place UPDATE(orphanRemoval clear→재추가)가
 * 실제 MySQL에서 자식 테이블까지 올바르게 재구성되는지 확인한다. 단위 테스트(Mockito)로는 이 부분을
 * 검증할 수 없다 — orphanRemoval은 실제 Hibernate flush에서만 동작한다.
 *
 * <p>이 레포의 다른 {@code @SpringBootTest}처럼 {@code @Transactional}을 켜지 않는다 — 켜면
 * {@code @BeforeEach}부터 단언까지 세션 하나로 묶여, 승인 후 재조회가 실제 SELECT가 아니라 영속성
 * 컨텍스트에 남은 같은 자바 객체를 돌려줄 수 있다(그러면 UPDATE가 DB에 닿지 않아도 테스트가 통과한다).
 * 매 단언은 별도 트랜잭션으로 실제 재조회해야 하고, 격리는 {@code @BeforeEach}의 {@code DatabaseCleanUp}이
 * 맡는다. choices처럼 지연 로딩 연관관계가 필요한 곳은 {@link QuizRepository#findWithChoicesById}로
 * 같은 조회 안에서 즉시 로딩한다.
 */
@SpringBootTest
@Testcontainers
@ActiveProfiles("test")
class AuthoringApprovalIntegrationTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final AuthoringApprovalService approvalService;
    private final AuthoringDraftService draftService;
    private final QuizRepository quizRepository;
    private final QuizStepRepository quizStepRepository;
    private final QuizDraftRepository quizDraftRepository;
    private final GenerationJobRepository generationJobRepository;
    private final DatabaseCleanUp databaseCleanUp;

    // 생성자 파라미터 수를 checkstyle 제한(7개) 안에 두기 위해 필드 주입을 쓴다 — course_id 도입(#234)으로
    // 새로 필요해진 의존성이라 생성자에 추가하면 한도를 넘는다.
    @Autowired
    private CourseRepository courseRepository;

    // Bean이 아닌 로컬 인스턴스 — 생성자 파라미터 수를 checkstyle 제한(7개) 안에 두기 위해서다.
    // GeneratedQuizSet은 record 역직렬화만 필요해 Spring이 커스터마이즈한 기본 ObjectMapper와 차이가 없다.
    private final ObjectMapper objectMapper = new ObjectMapper();

    AuthoringApprovalIntegrationTest(
            @Autowired AuthoringApprovalService approvalService,
            @Autowired AuthoringDraftService draftService,
            @Autowired QuizRepository quizRepository,
            @Autowired QuizStepRepository quizStepRepository,
            @Autowired QuizDraftRepository quizDraftRepository,
            @Autowired GenerationJobRepository generationJobRepository,
            @Autowired DatabaseCleanUp databaseCleanUp) {
        this.approvalService = approvalService;
        this.draftService = draftService;
        this.quizRepository = quizRepository;
        this.quizStepRepository = quizStepRepository;
        this.quizDraftRepository = quizDraftRepository;
        this.generationJobRepository = generationJobRepository;
        this.databaseCleanUp = databaseCleanUp;
    }

    @BeforeEach
    void cleanSeedData() {
        databaseCleanUp.execute();
        // 승인(NEW draft materialize)이 QuizPersister의 기본 코스 해석 경로를 타므로, 매 테스트마다
        // 최소 코스 1개는 있어야 한다 — DatabaseCleanUp이 Flyway 시드 코스까지 지운다.
        courseRepository.save(Course.create("운영체제", "CS"));
    }

    @Test
    @DisplayName("개선 draft 승인은 원본 quiz id를 보존하며 내용만 교체한다")
    void 개선_draft_승인은_원본_quiz_id를_보존하며_내용만_교체한다() throws Exception {
        int stepOrder = 1;
        Long courseId = courseRepository.findFirstByOrderByIdAsc().orElseThrow().getId();
        quizStepRepository.save(QuizStep.create(stepOrder, courseId, "운영체제", 3));
        List<Quiz> step = QuizFixture.step(stepOrder);
        quizRepository.saveAll(step);
        Quiz targetQuiz = step.get(2); // multipleChoiceQuiz, 3번 슬롯
        Long otherQuizId = step.get(0).getId();
        String otherQuestionTextBefore = step.get(0).getQuestionText();

        QuizDraft draft = draftService.createImproveDraft(1L, targetQuiz, "운영체제");
        String improvedPayload = draft.getCurrentPayload().replace(targetQuiz.getQuestionText(), "개선된 질문");
        draft.applyRevision(improvedPayload);
        quizDraftRepository.saveAndFlush(draft);

        approvalService.approve(9L, draft.getId());

        // findWithChoicesById는 approve()와 별개의 새 조회 — 여기서 관리 객체를 재사용하면
        // UPDATE가 DB에 닿았는지 증명하지 못한다(리뷰 지적, #174).
        Quiz updated = quizRepository.findWithChoicesById(targetQuiz.getId()).orElseThrow();
        assertThat(updated.getQuestionText()).isEqualTo("개선된 질문");
        assertThat(updated.getChoices()).hasSize(4);
        assertThat(quizDraftRepository.findById(draft.getId()).orElseThrow().getStatus())
                .isEqualTo(QuizDraftStatus.APPROVED);

        Quiz other = quizRepository.findById(otherQuizId).orElseThrow();
        assertThat(other.getQuestionText()).isEqualTo(otherQuestionTextBefore);
    }

    @Test
    @DisplayName("신규 draft 승인은 새 스텝을 INSERT한다")
    void 신규_draft_승인은_새_스텝을_INSERT한다() throws Exception {
        long stepCountBefore = quizStepRepository.count();
        long quizCountBefore = quizRepository.count();

        GenerationJob job = generationJobRepository.save(GenerationJob.createGenerate(1L, "네트워크", "prompt"));
        GeneratedQuizSet set = objectMapper.readValue(GeneratedQuizJsonFixture.validSetJson(), GeneratedQuizSet.class);
        QuizDraft draft = draftService.createFromGenerate(job, set); // job.attachDraft(...) — 아직 detached라 DB엔 미반영
        // 잡을 QUEUED로 남겨두면 승인 가드(활성 잡 검사)가 막는다 — 실제 흐름처럼 종결 상태로 만든다.
        job.succeed(BridgeCli.CLAUDE, Instant.now());
        // 클래스에 @Transactional이 없어 앞선 mutation들이 같은 세션의 dirty-checking으로 자동 flush되지
        // 않는다 — draftId·상태 변경을 한 번에 명시적으로 반영한다.
        generationJobRepository.save(job);

        approvalService.approve(9L, draft.getId());

        assertThat(quizStepRepository.count()).isEqualTo(stepCountBefore + 1);
        assertThat(quizRepository.count()).isEqualTo(quizCountBefore + 5);
        assertThat(quizDraftRepository.findById(draft.getId()).orElseThrow().getStatus())
                .isEqualTo(QuizDraftStatus.APPROVED);
    }

    @Test
    @DisplayName("뼈대 스텝 draft 승인은 quiz와 quiz_step을 INSERT하지 않는다")
    void 뼈대_스텝_draft_승인은_라이브에_쓰지_않는다() throws Exception {
        long stepCountBefore = quizStepRepository.count();
        long quizCountBefore = quizRepository.count();
        GeneratedQuizSet set = objectMapper.readValue(GeneratedQuizJsonFixture.light3SetJson(), GeneratedQuizSet.class);
        QuizDraft draft = quizDraftRepository.saveAndFlush(
                QuizDraft.createForOutlineStep("네트워크", objectMapper.writeValueAsString(set), QuizPreset.LIGHT_3, 1L));

        approvalService.approve(9L, draft.getId());

        assertThat(quizStepRepository.count()).isEqualTo(stepCountBefore);
        assertThat(quizRepository.count()).isEqualTo(quizCountBefore);
        assertThat(quizDraftRepository.findById(draft.getId()).orElseThrow().getStatus())
                .isEqualTo(QuizDraftStatus.APPROVED);
    }
}
