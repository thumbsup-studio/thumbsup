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
import org.springframework.transaction.annotation.Transactional;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.DatabaseCleanUp;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizFixture;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;

/**
 * 승인(materialize) 통합 테스트 — 핵심 리스크인 IMPROVE의 in-place UPDATE(orphanRemoval clear→재추가)가
 * 실제 MySQL에서 자식 테이블까지 올바르게 재구성되는지 확인한다. 단위 테스트(Mockito)로는 이 부분을
 * 검증할 수 없다 — orphanRemoval은 실제 Hibernate flush에서만 동작한다.
 *
 * <p>이 클래스는 (다른 {@code @SpringBootTest}와 달리, MockMvc를 쓰지 않으므로) {@code @Transactional}을
 * 켠다 — 승인 후 {@code quiz.getChoices()} 같은 지연 로딩 연관관계를 같은 세션 안에서 그대로 확인하기
 * 위해서다. 테스트 종료 시 자동 롤백되고, {@code @BeforeEach}의 {@code DatabaseCleanUp}이 그 전에도
 * 독립성을 보장한다.
 */
@SpringBootTest
@Testcontainers
@ActiveProfiles("test")
@Transactional
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
    }

    @Test
    @DisplayName("개선 draft 승인은 원본 quiz id를 보존하며 내용만 교체한다")
    void 개선_draft_승인은_원본_quiz_id를_보존하며_내용만_교체한다() throws Exception {
        int stepOrder = 1;
        quizStepRepository.save(QuizStep.create(stepOrder, "운영체제", 3));
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

        Quiz updated = quizRepository.findById(targetQuiz.getId()).orElseThrow();
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
        QuizDraft draft = draftService.createFromGenerate(job, set);
        // 잡을 QUEUED로 남겨두면 승인 가드(활성 잡 검사)가 막는다 — 실제 흐름처럼 종결 상태로 만든다.
        job.succeed(BridgeCli.CLAUDE, Instant.now());

        approvalService.approve(9L, draft.getId());

        assertThat(quizStepRepository.count()).isEqualTo(stepCountBefore + 1);
        assertThat(quizRepository.count()).isEqualTo(quizCountBefore + 5);
        assertThat(quizDraftRepository.findById(draft.getId()).orElseThrow().getStatus())
                .isEqualTo(QuizDraftStatus.APPROVED);
    }
}
