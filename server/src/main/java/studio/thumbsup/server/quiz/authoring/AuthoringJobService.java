package studio.thumbsup.server.quiz.authoring;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.exception.CommonErrorType;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizErrorType;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.authoring.dto.BridgeJobResponse;
import studio.thumbsup.server.quiz.authoring.dto.BridgeResultResponse;
import studio.thumbsup.server.quiz.authoring.dto.JobStatusResponse;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;
import studio.thumbsup.server.quiz.generation.GeneratedQuizValidator;
import studio.thumbsup.server.quiz.generation.QuizGenerationException;

/**
 * 잡 큐(#174)의 유일한 진입점 — 대시보드가 잡을 만들고(enqueue*), 브리지가 폴링·결과 제출(claimNext/submitResult/failJob)하고,
 * 누구나 상태를 조회(getJobWithExpiry)하는 모든 흐름이 이 서비스를 거친다.
 *
 * <p>만료는 스케줄러 없이 lazy하게 평가한다 — QUEUED 30분·RUNNING 10분을 넘긴 잡은 가드·조회 시점에
 * 비로소 FAILED로 굳는다. {@link #claimNext}는 {@link GenerationJobRepository#pickNextQueued}의
 * {@code FOR UPDATE SKIP LOCKED} 락이 이 메서드의 {@code @Transactional} 경계가 끝날 때까지 유지되도록
 * pick과 {@code markRunning}을 한 트랜잭션 안에서 처리한다(#174 T1 리뷰에서 확립된 계약).
 */
@Service
public class AuthoringJobService {

    private static final String EXPIRY_MESSAGE = "시간 초과로 만료되었습니다";
    private static final Duration QUEUED_EXPIRY = Duration.ofMinutes(30);
    private static final Duration RUNNING_EXPIRY = Duration.ofMinutes(10);

    private final GenerationJobRepository generationJobRepository;
    private final QuizRepository quizRepository;
    private final QuizStepRepository quizStepRepository;
    private final AuthoringDraftService draftService;
    private final GeneratedQuizValidator validator;
    private final ObjectMapper objectMapper;
    private final Clock clock;

    public AuthoringJobService(
            GenerationJobRepository generationJobRepository,
            QuizRepository quizRepository,
            QuizStepRepository quizStepRepository,
            AuthoringDraftService draftService,
            GeneratedQuizValidator validator,
            ObjectMapper objectMapper,
            Clock clock) {
        this.generationJobRepository = generationJobRepository;
        this.quizRepository = quizRepository;
        this.quizStepRepository = quizStepRepository;
        this.draftService = draftService;
        this.validator = validator;
        this.objectMapper = objectMapper;
        this.clock = clock;
    }

    /** 잡 생성 결과를 컨트롤러에 돌려주는 값 — draft와 잡을 함께 만드는 유일한 진입점(enqueueImprove)의 반환 타입. */
    public record ImproveEnqueued(Long draftId, Long jobId) {}

    @Transactional
    public Long enqueueGenerate(Long userId, String topic) {
        String prompt = AuthoringPromptFactory.generatePrompt(topic);
        GenerationJob job = generationJobRepository.save(GenerationJob.createGenerate(userId, topic, prompt));
        return job.getId();
    }

    @Transactional
    public ImproveEnqueued enqueueImprove(Long userId, Long quizId, String instruction) {
        // PESSIMISTIC_WRITE로 원본 quiz를 잠근다(#174 I2) — 아직 draft가 없는 시점부터 동시 요청을
        // 직렬화해야 hasOpenImproveDraft check-then-act가 중복 improve draft를 만들지 않는다.
        Quiz sourceQuiz = quizRepository
                .findByIdForUpdate(quizId)
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
        if (draftService.hasOpenImproveDraft(quizId)) {
            throw new BusinessException(AuthoringErrorType.AUTHORING_IMPROVE_DRAFT_EXISTS);
        }

        QuizStep step = quizStepRepository
                .findByStepOrder(sourceQuiz.getStepOrder())
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
        QuizDraft draft = draftService.createImproveDraft(userId, sourceQuiz, step.getTopic());

        String prompt = improveReviewPrompt(sourceQuiz, step.getTopic(), draft.getCurrentPayload(), instruction);
        GenerationJob job =
                generationJobRepository.save(GenerationJob.createReview(userId, draft.getId(), instruction, prompt));
        return new ImproveEnqueued(draft.getId(), job.getId());
    }

    @Transactional
    public Long enqueueReview(Long userId, Long draftId, String feedback) {
        // PESSIMISTIC_WRITE로 draft를 잠근다(#174 I2) — 상태·활성잡 가드의 check-then-act race를 막는다.
        QuizDraft draft = draftService.getForUpdate(draftId);
        if (draft.getStatus() == QuizDraftStatus.APPROVED) {
            throw new BusinessException(AuthoringErrorType.AUTHORING_DRAFT_ALREADY_APPROVED);
        }
        guardDraftHasNoActiveJob(draftId, clock.instant());

        String prompt = reviewPromptForDraft(draft, feedback);
        GenerationJob job = generationJobRepository.save(GenerationJob.createReview(userId, draftId, feedback, prompt));
        return job.getId();
    }

    /**
     * pick과 상태 변경(markRunning)을 이 메서드의 트랜잭션 경계 안에서 함께 처리한다 — 분리하면
     * {@code SKIP LOCKED} 락이 조회 직후 풀려 동시 폴링과 경합할 수 있다.
     */
    @Transactional
    public Optional<GenerationJob> claimNext(Long userId) {
        Instant now = clock.instant();
        return generationJobRepository.pickNextQueued(userId).map(job -> {
            job.markRunning(now);
            return job;
        });
    }

    @Transactional
    public GenerationJob submitResult(Long userId, Long jobId, BridgeCli cli, String resultJson) {
        GenerationJob job = findJobOrThrow(jobId);
        guardOwnership(job, userId);
        guardClaimable(job);

        Instant now = clock.instant();
        try {
            if (job.getKind() == GenerationJobKind.GENERATE) {
                handleGenerateResult(job, resultJson);
            } else {
                handleReviewResult(job, resultJson);
            }
            job.succeed(cli, now);
        } catch (QuizGenerationException | JsonProcessingException e) {
            job.fail(cli, e.getMessage(), now);
        }
        return job;
    }

    @Transactional
    public GenerationJob failJob(Long userId, Long jobId, String error) {
        GenerationJob job = findJobOrThrow(jobId);
        guardOwnership(job, userId);
        guardClaimable(job);
        job.fail(null, error, clock.instant());
        return job;
    }

    /** 잡 상태는 팀원 누구나 조회할 수 있다 — assignee 제한 없음. */
    @Transactional
    public GenerationJob getJobWithExpiry(Long jobId) {
        GenerationJob job = findJobOrThrow(jobId);
        expireIfNeeded(job, clock.instant());
        return job;
    }

    /** 컨트롤러(#174 T7)가 엔티티를 직접 만지지 않도록 조회 결과를 DTO로 감싸 돌려준다. */
    @Transactional
    public JobStatusResponse getJobStatus(Long jobId) {
        return JobStatusResponse.from(getJobWithExpiry(jobId));
    }

    /** 컨트롤러(#174 T8)가 엔티티를 직접 만지지 않도록 claimNext 결과를 DTO로 감싸 돌려준다. */
    @Transactional
    public Optional<BridgeJobResponse> claimNextForBridge(Long userId) {
        return claimNext(userId).map(job -> BridgeJobResponse.from(job, readOutputSchema(job.getKind())));
    }

    /** 컨트롤러(#174 T8)가 엔티티를 직접 만지지 않도록 submitResult 결과를 DTO로 감싸 돌려준다. */
    @Transactional
    public BridgeResultResponse submitResultForBridge(Long userId, Long jobId, BridgeCli cli, String resultJson) {
        return BridgeResultResponse.from(submitResult(userId, jobId, cli, resultJson));
    }

    /** 컨트롤러(#174 T8)가 엔티티를 직접 만지지 않도록 반환값 없이 위임한다 — {@code /fail}은 항상 data:null. */
    @Transactional
    public void failJobForBridge(Long userId, Long jobId, String error) {
        failJob(userId, jobId, error);
    }

    /**
     * 로그 적재 가능 여부(#174 T8) — 잡 존재·소유권은 여기서 확인해 못 찾으면 404, 남의 잡이면 403이다.
     * RUNNING이 아니면(이미 종결된 잡에 뒤늦게 도착한 flush 등) 예외 없이 false만 돌려준다 — 컨트롤러가
     * 이 경우 append를 조용히 건너뛴다. 브리지의 finally 안전망 flush가 result 직후 늦게 도착해도
     * 500/409로 브리지를 놀라게 하지 않기 위한 선택이다(브리프에 명시 없어 T8 구현 시 판단, 리포트 참고).
     */
    @Transactional(readOnly = true)
    public boolean canAppendLogs(Long userId, Long jobId) {
        GenerationJob job = findJobOrThrow(jobId);
        guardOwnership(job, userId);
        return job.getStatus() == GenerationJobStatus.RUNNING;
    }

    private void handleGenerateResult(GenerationJob job, String resultJson) {
        GeneratedQuizSet generated = validator.parse(resultJson);
        validator.validateSet(generated);
        draftService.createFromGenerate(job, generated);
    }

    private void handleReviewResult(GenerationJob job, String resultJson) throws JsonProcessingException {
        String cleaned = validator.stripMarkdownFence(resultJson);
        ReviewResult result = objectMapper.readValue(cleaned, ReviewResult.class);
        validateReviewResult(job, result);
        draftService.applyReview(job, result);
    }

    private void validateReviewResult(GenerationJob job, ReviewResult result) {
        QuizDraft draft = draftService.getOrThrow(job.getDraftId());
        if (draft.getOrigin() == QuizDraftOrigin.NEW) {
            validator.validateSet(new GeneratedQuizSet(result.quizzes()));
            return;
        }
        List<GeneratedQuizSet.GeneratedQuiz> quizzes = result.quizzes();
        if (quizzes == null || quizzes.size() != 1) {
            throw new QuizGenerationException(
                    "개선 draft의 REVIEW 결과는 문제 1개여야 합니다: " + (quizzes == null ? 0 : quizzes.size()) + "개");
        }
        Quiz sourceQuiz = quizRepository
                .findById(draft.getSourceQuizId())
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
        validator.validateSingle(quizzes.get(0), sourceQuiz.getType(), sourceQuiz.getDifficulty());
    }

    private JsonNode readOutputSchema(GenerationJobKind kind) {
        String schema =
                kind == GenerationJobKind.GENERATE ? AuthoringOutputSchemas.GENERATE : AuthoringOutputSchemas.REVIEW;
        try {
            return objectMapper.readTree(schema);
        } catch (JsonProcessingException e) {
            throw new QuizGenerationException("output schema를 JSON으로 파싱하지 못했습니다.", e);
        }
    }

    private GenerationJob findJobOrThrow(Long jobId) {
        return generationJobRepository
                .findById(jobId)
                .orElseThrow(() -> new BusinessException(AuthoringErrorType.AUTHORING_JOB_NOT_FOUND));
    }

    private void guardOwnership(GenerationJob job, Long userId) {
        if (!job.getAssigneeUserId().equals(userId)) {
            throw new BusinessException(CommonErrorType.FORBIDDEN);
        }
    }

    private void guardClaimable(GenerationJob job) {
        if (job.getStatus() != GenerationJobStatus.RUNNING) {
            throw new BusinessException(AuthoringErrorType.AUTHORING_JOB_NOT_CLAIMABLE);
        }
    }

    /** package-private — {@code AuthoringApprovalService}(T6)의 승인 가드가 재사용한다. */
    void guardDraftHasNoActiveJob(Long draftId, Instant now) {
        List<GenerationJob> activeJobs = generationJobRepository.findByDraftIdAndStatusIn(
                draftId, List.of(GenerationJobStatus.QUEUED, GenerationJobStatus.RUNNING));
        activeJobs.forEach(job -> expireIfNeeded(job, now));
        boolean stillActive = activeJobs.stream().anyMatch(GenerationJob::isActive);
        if (stillActive) {
            throw new BusinessException(AuthoringErrorType.AUTHORING_DRAFT_JOB_ACTIVE);
        }
    }

    private void expireIfNeeded(GenerationJob job, Instant now) {
        boolean queuedExpired = job.getStatus() == GenerationJobStatus.QUEUED
                && Duration.between(job.getCreatedAt(), now).compareTo(QUEUED_EXPIRY) > 0;
        boolean runningExpired = job.getStatus() == GenerationJobStatus.RUNNING
                && Duration.between(job.getStartedAt(), now).compareTo(RUNNING_EXPIRY) > 0;
        if (queuedExpired || runningExpired) {
            job.fail(null, EXPIRY_MESSAGE, now);
        }
    }

    private String reviewPromptForDraft(QuizDraft draft, String feedback) {
        if (draft.getOrigin() == QuizDraftOrigin.IMPROVE) {
            Quiz sourceQuiz = quizRepository
                    .findById(draft.getSourceQuizId())
                    .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
            QuizStep step = quizStepRepository
                    .findByStepOrder(sourceQuiz.getStepOrder())
                    .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
            return improveReviewPrompt(sourceQuiz, step.getTopic(), draft.getCurrentPayload(), feedback);
        }
        return AuthoringPromptFactory.reviewPrompt(draft.getTopic(), draft.getCurrentPayload(), feedback, List.of());
    }

    private String improveReviewPrompt(Quiz sourceQuiz, String stepTopic, String currentPayloadJson, String feedback) {
        List<String> siblingQuestions = siblingQuestionTexts(sourceQuiz);
        return AuthoringPromptFactory.reviewPrompt(stepTopic, currentPayloadJson, feedback, siblingQuestions);
    }

    private List<String> siblingQuestionTexts(Quiz sourceQuiz) {
        return quizRepository.findByStepOrderOrderBySlotOrderAsc(sourceQuiz.getStepOrder()).stream()
                .filter(quiz -> !quiz.getId().equals(sourceQuiz.getId()))
                .map(Quiz::getQuestionText)
                .toList();
    }
}
