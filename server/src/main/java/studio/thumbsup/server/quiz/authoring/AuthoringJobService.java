package studio.thumbsup.server.quiz.authoring;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Clock;
import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.Set;
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
import studio.thumbsup.server.quiz.generation.QuizPreset;

/** 잡 생성·폴링·결과 제출·상태 조회를 담당하는 저작 잡 큐의 유일한 진입점. */
@Service
public class AuthoringJobService {

    private final GenerationJobRepository generationJobRepository;
    private final QuizRepository quizRepository;
    private final QuizStepRepository quizStepRepository;
    private final AuthoringDraftService draftService;
    private final GeneratedQuizValidator validator;
    private final ObjectMapper objectMapper;
    private final GenerationJobActivityGuard activityGuard;
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
        this.activityGuard = new GenerationJobActivityGuard(generationJobRepository);
        this.clock = clock;
    }

    public record ImproveEnqueued(Long draftId, Long jobId) {}

    @Transactional
    public Long enqueueGenerate(Long userId, String topic) {
        String prompt = AuthoringPromptFactory.generatePrompt(topic);
        GenerationJob job = generationJobRepository.save(GenerationJob.createGenerate(userId, topic, prompt));
        return job.getId();
    }

    @Transactional
    public Long enqueueOutline(Long userId, Long outlineId) {
        AuthoringOutline outline = draftService.getOutlineForUpdate(outlineId);
        if (outline.isPublished()) {
            throw new BusinessException(AuthoringErrorType.AUTHORING_OUTLINE_PUBLISHED);
        }
        if (draftService.hasFilledOutlineSteps(outlineId)) {
            throw new BusinessException(AuthoringErrorType.AUTHORING_OUTLINE_STEP_FILLED);
        }
        activityGuard.guardOutline(outlineId, clock.instant());

        String prompt =
                AuthoringPromptFactory.outlinePrompt(outline.getTitle(), outline.getCategory(), outline.getTocSource());
        GenerationJob job = generationJobRepository.save(GenerationJob.createOutline(userId, outlineId, prompt));
        return job.getId();
    }

    @Transactional
    public Long enqueueStepGenerate(Long userId, Long stepId, QuizPreset preset) {
        if (preset == null) {
            throw new BusinessException(CommonErrorType.INVALID_INPUT);
        }
        AuthoringOutlineStep step = draftService.getOutlineStepOrThrow(stepId);
        AuthoringOutline outline = draftService.getOutlineForUpdate(step.getOutlineId());
        if (outline.isPublished()) {
            throw new BusinessException(AuthoringErrorType.AUTHORING_OUTLINE_PUBLISHED);
        }
        if (step.getDraftId() != null) {
            throw new BusinessException(AuthoringErrorType.AUTHORING_OUTLINE_STEP_FILLED);
        }
        activityGuard.guardOutlineStep(stepId, clock.instant());
        activityGuard.guardOutline(step.getOutlineId(), clock.instant());

        OutlineStepContext context = draftService.outlineStepContext(stepId);
        String prompt = AuthoringPromptFactory.generatePrompt(context, preset);
        GenerationJob job = generationJobRepository.save(
                GenerationJob.createStepGenerate(userId, stepId, step.getTopic(), preset, prompt));
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
        activityGuard.guardDraft(draftId, clock.instant());

        String prompt = reviewPromptForDraft(draft, feedback);
        GenerationJob job = generationJobRepository.save(GenerationJob.createReview(userId, draftId, feedback, prompt));
        return job.getId();
    }

    /** pick과 markRunning을 같은 트랜잭션에서 처리해 SKIP LOCKED 경쟁을 막는다. */
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
            } else if (job.getKind() == GenerationJobKind.OUTLINE) {
                handleOutlineResult(job, resultJson);
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
        activityGuard.expireIfNeeded(job, clock.instant());
        return job;
    }

    @Transactional
    public JobStatusResponse getJobStatus(Long jobId) {
        return JobStatusResponse.from(getJobWithExpiry(jobId));
    }

    @Transactional
    public Optional<BridgeJobResponse> claimNextForBridge(Long userId) {
        return claimNext(userId).map(job -> BridgeJobResponse.from(job, readOutputSchema(job)));
    }

    @Transactional
    public BridgeResultResponse submitResultForBridge(Long userId, Long jobId, BridgeCli cli, String resultJson) {
        return BridgeResultResponse.from(submitResult(userId, jobId, cli, resultJson));
    }

    @Transactional
    public void failJobForBridge(Long userId, Long jobId, String error) {
        failJob(userId, jobId, error);
    }

    /** 로그 적재 전 잡 존재·소유권을 확인하고 RUNNING 여부를 반환한다. */
    @Transactional(readOnly = true)
    public boolean canAppendLogs(Long userId, Long jobId) {
        GenerationJob job = findJobOrThrow(jobId);
        guardOwnership(job, userId);
        return job.getStatus() == GenerationJobStatus.RUNNING;
    }

    private void handleGenerateResult(GenerationJob job, String resultJson) {
        GeneratedQuizSet generated = validator.parse(resultJson);
        validator.validateSet(generated, job.getPreset());
        if (job.getOutlineStepId() == null) {
            draftService.createFromGenerate(job, generated);
        } else {
            draftService.createFromGenerate(job, generated, job.getPreset());
        }
    }

    private void handleReviewResult(GenerationJob job, String resultJson) throws JsonProcessingException {
        String cleaned = validator.stripMarkdownFence(resultJson);
        ReviewResult result = objectMapper.readValue(cleaned, ReviewResult.class);
        validateReviewResult(job, result);
        draftService.applyReview(job, result);
    }

    private void handleOutlineResult(GenerationJob job, String resultJson) throws JsonProcessingException {
        String cleaned = validator.stripMarkdownFence(resultJson);
        OutlineResult result = objectMapper.readValue(cleaned, OutlineResult.class);
        List<AuthoringOutlineStep> steps = validatedOutlineSteps(job.getOutlineId(), result);
        // 검사와 교체 사이에 스텝 채우기 결과가 draft를 붙이면 그 draft가 고아가 된다 —
        // 스텝 생성 경로와 같은 뼈대 행을 잠가 두 경로를 직렬화한다.
        draftService.getOutlineForUpdate(job.getOutlineId());
        if (draftService.hasFilledOutlineSteps(job.getOutlineId())) {
            throw new QuizGenerationException("잡 실행 중 문제가 채워진 뼈대는 재생성할 수 없습니다.");
        }
        draftService.replaceOutlineSteps(job.getOutlineId(), steps);
    }

    private List<AuthoringOutlineStep> validatedOutlineSteps(Long outlineId, OutlineResult result) {
        List<OutlineResult.OutlineStepResult> results = result.steps();
        if (results == null || results.size() < 3 || results.size() > 20) {
            throw new QuizGenerationException(
                    "뼈대 스텝 수는 3~20개여야 합니다: %d개".formatted(results == null ? 0 : results.size()));
        }

        Set<String> topics = new HashSet<>();
        List<AuthoringOutlineStep> steps = new java.util.ArrayList<>();
        for (int index = 0; index < results.size(); index++) {
            steps.add(validatedOutlineStep(outlineId, index, results.get(index), topics));
        }
        return steps;
    }

    private AuthoringOutlineStep validatedOutlineStep(
            Long outlineId, int index, OutlineResult.OutlineStepResult resultStep, Set<String> topics) {
        if (resultStep == null
                || resultStep.topic() == null
                || resultStep.topic().isBlank()) {
            throw new QuizGenerationException("%d번 스텝의 topic이 비어 있습니다.".formatted(index + 1));
        }
        String topic = resultStep.topic().trim();
        if (topic.length() > 30) {
            throw new QuizGenerationException("%d번 스텝의 topic은 30자 이내여야 합니다.".formatted(index + 1));
        }
        if (!topics.add(topic.toLowerCase(Locale.ROOT))) {
            throw new QuizGenerationException("뼈대 스텝 topic이 중복됩니다: %s".formatted(topic));
        }
        if (resultStep.learningGoal() == null || resultStep.learningGoal().isBlank()) {
            throw new QuizGenerationException("%d번 스텝의 learningGoal이 비어 있습니다.".formatted(index + 1));
        }
        String learningGoal = resultStep.learningGoal().trim();
        if (learningGoal.length() > 500) {
            throw new QuizGenerationException("%d번 스텝의 learningGoal은 500자 이내여야 합니다.".formatted(index + 1));
        }
        return AuthoringOutlineStep.create(outlineId, index + 1, topic, learningGoal);
    }

    private void validateReviewResult(GenerationJob job, ReviewResult result) {
        QuizDraft draft = draftService.getOrThrow(job.getDraftId());
        if (draft.getOrigin() != QuizDraftOrigin.IMPROVE) {
            validator.validateSet(new GeneratedQuizSet(result.quizzes()), draft.getPreset());
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

    private JsonNode readOutputSchema(GenerationJob job) {
        String schema;
        if (job.getKind() == GenerationJobKind.GENERATE) {
            schema = AuthoringOutputSchemas.generateFor(job.getPreset());
        } else if (job.getKind() == GenerationJobKind.OUTLINE) {
            schema = AuthoringOutputSchemas.OUTLINE;
        } else {
            schema = AuthoringOutputSchemas.REVIEW;
        }
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

    /** package-private — {@code AuthoringApprovalService}의 승인 가드가 재사용한다. */
    void guardDraftHasNoActiveJob(Long draftId, Instant now) {
        activityGuard.guardDraft(draftId, now);
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
        List<String> siblingTopics = draft.getOrigin() == QuizDraftOrigin.OUTLINE_STEP
                ? draftService.outlineSiblingTopics(draft.getId())
                : List.of();
        return AuthoringPromptFactory.reviewPrompt(
                draft.getTopic(), draft.getCurrentPayload(), feedback, siblingTopics);
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
