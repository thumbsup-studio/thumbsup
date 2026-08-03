package studio.thumbsup.server.quiz.authoring;

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.exception.CommonErrorType;
import studio.thumbsup.server.quiz.authoring.dto.OutlineCreatedResponse;
import studio.thumbsup.server.quiz.authoring.dto.OutlineDetailResponse;
import studio.thumbsup.server.quiz.authoring.dto.OutlineListResponse;
import studio.thumbsup.server.quiz.authoring.dto.OutlineStepResponse;
import studio.thumbsup.server.quiz.authoring.dto.OutlineSummaryResponse;
import studio.thumbsup.server.quiz.authoring.dto.StepCreatedResponse;

/** 발행 전 뼈대의 조회·편집과 스텝별 채움 상태 파생을 담당한다. */
@Service
public class AuthoringOutlineService {

    private static final int TEMP_ORDER_NO = -1;
    private static final List<GenerationJobStatus> ACTIVE_STATUSES =
            List.of(GenerationJobStatus.QUEUED, GenerationJobStatus.RUNNING);

    private final AuthoringOutlineRepository outlineRepository;
    private final AuthoringOutlineStepRepository stepRepository;
    private final QuizDraftRepository draftRepository;
    private final GenerationJobRepository jobRepository;
    private final AuthoringJobService jobService;

    public AuthoringOutlineService(
            AuthoringOutlineRepository outlineRepository,
            AuthoringOutlineStepRepository stepRepository,
            QuizDraftRepository draftRepository,
            GenerationJobRepository jobRepository,
            AuthoringJobService jobService) {
        this.outlineRepository = outlineRepository;
        this.stepRepository = stepRepository;
        this.draftRepository = draftRepository;
        this.jobRepository = jobRepository;
        this.jobService = jobService;
    }

    @Transactional
    public OutlineCreatedResponse createOutline(Long userId, String title, String category, String toc) {
        AuthoringOutline outline = outlineRepository.save(AuthoringOutline.create(title, category, toc, userId));
        Long jobId = jobService.enqueueOutline(userId, outline.getId());
        return new OutlineCreatedResponse(outline.getId(), jobId);
    }

    @Transactional(readOnly = true)
    public OutlineListResponse listSummaries() {
        List<AuthoringOutline> outlines = outlineRepository.findAllByOrderByIdDesc();
        List<Long> outlineIds = outlines.stream().map(AuthoringOutline::getId).toList();
        List<AuthoringOutlineStep> steps = outlineIds.isEmpty()
                ? List.of()
                : stepRepository.findByOutlineIdInOrderByOutlineIdAscOrderNoAsc(outlineIds);
        Map<Long, StepState> states = deriveStates(steps);
        Map<Long, List<AuthoringOutlineStep>> stepsByOutline = groupByOutline(steps);
        return new OutlineListResponse(outlines.stream()
                .map(outline -> toSummary(outline, stepsByOutline.getOrDefault(outline.getId(), List.of()), states))
                .toList());
    }

    @Transactional(readOnly = true)
    public OutlineDetailResponse getDetail(Long outlineId) {
        AuthoringOutline outline = findOutlineOrThrow(outlineId);
        List<AuthoringOutlineStep> steps = stepRepository.findByOutlineIdOrderByOrderNoAsc(outlineId);
        Map<Long, StepState> states = deriveStates(steps);
        List<OutlineStepResponse> stepResponses =
                steps.stream().map(step -> toStepResponse(step, states)).toList();
        return new OutlineDetailResponse(
                outline.getId(),
                outline.getTitle(),
                outline.getCategory(),
                outline.getStatus().name(),
                outline.getTocSource(),
                stepResponses);
    }

    @Transactional
    public Long regenerate(Long userId, Long outlineId) {
        AuthoringOutline outline = getOutlineForUpdate(outlineId);
        guardNotPublished(outline);
        return jobService.enqueueOutline(userId, outlineId);
    }

    @Transactional
    public void updateOutline(Long outlineId, String title, String category) {
        AuthoringOutline outline = getOutlineForUpdate(outlineId);
        guardNotPublished(outline);
        if (title != null) {
            outline.changeTitle(title);
        }
        if (category != null) {
            outline.changeCategory(category);
        }
    }

    @Transactional
    public StepCreatedResponse addStep(Long outlineId, String topic) {
        AuthoringOutline outline = getOutlineForUpdate(outlineId);
        guardNotPublished(outline);
        List<AuthoringOutlineStep> steps = stepRepository.findByOutlineIdOrderByOrderNoAsc(outlineId);
        int nextOrderNo =
                steps.stream().mapToInt(AuthoringOutlineStep::getOrderNo).max().orElse(0) + 1;
        AuthoringOutlineStep saved =
                stepRepository.save(AuthoringOutlineStep.create(outlineId, nextOrderNo, topic, null));
        return new StepCreatedResponse(saved.getId());
    }

    @Transactional
    public void updateStep(Long stepId, String topic) {
        AuthoringOutlineStep step = findStepOrThrow(stepId);
        AuthoringOutline outline = getOutlineForUpdate(step.getOutlineId());
        guardNotPublished(outline);
        step.changeTopic(topic);
    }

    @Transactional
    public void deleteStep(Long stepId) {
        AuthoringOutlineStep step = findStepOrThrow(stepId);
        AuthoringOutline outline = getOutlineForUpdate(step.getOutlineId());
        guardNotPublished(outline);
        if (!jobRepository
                .findByOutlineStepIdAndStatusIn(stepId, ACTIVE_STATUSES)
                .isEmpty()) {
            throw new BusinessException(AuthoringErrorType.AUTHORING_DRAFT_JOB_ACTIVE);
        }
        if (isApproved(step)) {
            throw new BusinessException(AuthoringErrorType.AUTHORING_OUTLINE_STEP_FILLED);
        }
        stepRepository.delete(step);
    }

    @Transactional
    public void reorderStep(Long stepId, String direction) {
        AuthoringOutlineStep step = findStepOrThrow(stepId);
        AuthoringOutline outline = getOutlineForUpdate(step.getOutlineId());
        guardNotPublished(outline);
        boolean moveUp = parseDirection(direction);
        List<AuthoringOutlineStep> steps = stepRepository.findByOutlineIdOrderByOrderNoAsc(step.getOutlineId());
        int index = indexOf(steps, stepId);
        int neighbourIndex = moveUp ? index - 1 : index + 1;
        if (index < 0 || neighbourIndex < 0 || neighbourIndex >= steps.size()) {
            throw new BusinessException(CommonErrorType.INVALID_INPUT);
        }

        AuthoringOutlineStep neighbour = steps.get(neighbourIndex);
        int originalOrderNo = step.getOrderNo();
        int neighbourOrderNo = neighbour.getOrderNo();
        // UNIQUE(outline_id, order_no) 때문에 두 행을 바로 맞바꿀 수 없어 임시 번호를 경유한다.
        step.changeOrderNo(TEMP_ORDER_NO);
        stepRepository.flush();
        neighbour.changeOrderNo(originalOrderNo);
        stepRepository.flush();
        step.changeOrderNo(neighbourOrderNo);
        stepRepository.flush();
    }

    private AuthoringOutline getOutlineForUpdate(Long outlineId) {
        return outlineRepository
                .findByIdForUpdate(outlineId)
                .orElseThrow(() -> new BusinessException(AuthoringErrorType.AUTHORING_OUTLINE_NOT_FOUND));
    }

    private AuthoringOutline findOutlineOrThrow(Long outlineId) {
        return outlineRepository
                .findById(outlineId)
                .orElseThrow(() -> new BusinessException(AuthoringErrorType.AUTHORING_OUTLINE_NOT_FOUND));
    }

    private AuthoringOutlineStep findStepOrThrow(Long stepId) {
        return stepRepository
                .findById(stepId)
                .orElseThrow(() -> new BusinessException(AuthoringErrorType.AUTHORING_OUTLINE_STEP_NOT_FOUND));
    }

    private void guardNotPublished(AuthoringOutline outline) {
        if (outline.isPublished()) {
            throw new BusinessException(AuthoringErrorType.AUTHORING_OUTLINE_PUBLISHED);
        }
    }

    private boolean isApproved(AuthoringOutlineStep step) {
        return step.getDraftId() != null
                && draftRepository
                        .findById(step.getDraftId())
                        .map(draft -> draft.getStatus() == QuizDraftStatus.APPROVED)
                        .orElse(false);
    }

    private boolean parseDirection(String direction) {
        if ("UP".equals(direction)) {
            return true;
        }
        if ("DOWN".equals(direction)) {
            return false;
        }
        throw new BusinessException(CommonErrorType.INVALID_INPUT);
    }

    private int indexOf(List<AuthoringOutlineStep> steps, Long stepId) {
        for (int index = 0; index < steps.size(); index++) {
            if (steps.get(index).getId().equals(stepId)) {
                return index;
            }
        }
        return -1;
    }

    private Map<Long, List<AuthoringOutlineStep>> groupByOutline(List<AuthoringOutlineStep> steps) {
        Map<Long, List<AuthoringOutlineStep>> grouped = new HashMap<>();
        steps.forEach(step -> grouped.computeIfAbsent(step.getOutlineId(), ignored -> new java.util.ArrayList<>())
                .add(step));
        return grouped;
    }

    private Map<Long, StepState> deriveStates(List<AuthoringOutlineStep> steps) {
        if (steps.isEmpty()) {
            return Map.of();
        }
        Set<Long> draftIds = steps.stream()
                .map(AuthoringOutlineStep::getDraftId)
                .filter(java.util.Objects::nonNull)
                .collect(java.util.stream.Collectors.toSet());
        Map<Long, QuizDraft> drafts = draftIds.isEmpty()
                ? Map.of()
                : draftRepository.findByIdIn(draftIds).stream()
                        .collect(java.util.stream.Collectors.toMap(QuizDraft::getId, draft -> draft));
        Set<Long> stepIds =
                new HashSet<>(steps.stream().map(AuthoringOutlineStep::getId).toList());
        Map<Long, GenerationJob> jobs =
                jobRepository.findByOutlineStepIdInAndStatusIn(stepIds, ACTIVE_STATUSES).stream()
                        .collect(java.util.stream.Collectors.toMap(
                                GenerationJob::getOutlineStepId, job -> job, (first, ignored) -> first));
        Map<Long, StepState> states = new HashMap<>();
        steps.forEach(step -> states.put(step.getId(), deriveState(step, drafts, jobs)));
        return states;
    }

    private StepState deriveState(
            AuthoringOutlineStep step, Map<Long, QuizDraft> drafts, Map<Long, GenerationJob> jobs) {
        if (step.getDraftId() != null && drafts.containsKey(step.getDraftId())) {
            QuizDraftStatus status = drafts.get(step.getDraftId()).getStatus();
            OutlineStepFillState fillState =
                    status == QuizDraftStatus.APPROVED ? OutlineStepFillState.APPROVED : OutlineStepFillState.REVIEWING;
            return new StepState(fillState, step.getDraftId(), null);
        }
        GenerationJob activeJob = jobs.get(step.getId());
        if (activeJob != null) {
            return new StepState(OutlineStepFillState.GENERATING, null, activeJob.getId());
        }
        return new StepState(OutlineStepFillState.EMPTY, null, null);
    }

    private OutlineSummaryResponse toSummary(
            AuthoringOutline outline, List<AuthoringOutlineStep> steps, Map<Long, StepState> states) {
        int approvedStepCount = (int) steps.stream()
                .map(step -> states.get(step.getId()))
                .filter(state -> state.fillState() == OutlineStepFillState.APPROVED)
                .count();
        return new OutlineSummaryResponse(
                outline.getId(),
                outline.getTitle(),
                outline.getCategory(),
                outline.getStatus().name(),
                steps.size(),
                approvedStepCount);
    }

    private OutlineStepResponse toStepResponse(AuthoringOutlineStep step, Map<Long, StepState> states) {
        StepState state = states.get(step.getId());
        return new OutlineStepResponse(
                step.getId(),
                step.getOrderNo(),
                step.getTopic(),
                step.getLearningGoal(),
                state.fillState(),
                state.draftId(),
                state.activeJobId());
    }

    private record StepState(OutlineStepFillState fillState, Long draftId, Long activeJobId) {}
}
