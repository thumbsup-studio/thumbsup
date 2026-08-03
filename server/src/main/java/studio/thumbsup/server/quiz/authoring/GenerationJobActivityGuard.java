package studio.thumbsup.server.quiz.authoring;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import studio.thumbsup.server.common.exception.BusinessException;

/**
 * "이 대상에 아직 도는 잡이 있는가"를 판정하는 가드 모음. 만료는 스케줄러 없이 lazy하게 평가한다 —
 * QUEUED 30분·RUNNING 10분을 넘긴 잡은 가드·조회 시점에 비로소 FAILED로 굳는다.
 *
 * <p>draft·뼈대·뼈대 스텝 세 축이 같은 판정 로직을 공유하므로 {@code AuthoringJobService}에서 분리했다.
 * 상태 없는 로직이라 빈으로 등록하지 않고 서비스가 직접 만든다 — 생성자 인자를 늘리지 않기 위함이다.
 */
class GenerationJobActivityGuard {

    private static final String EXPIRY_MESSAGE = "시간 초과로 만료되었습니다";
    private static final Duration QUEUED_EXPIRY = Duration.ofMinutes(30);
    private static final Duration RUNNING_EXPIRY = Duration.ofMinutes(10);
    private static final List<GenerationJobStatus> ACTIVE_STATUSES =
            List.of(GenerationJobStatus.QUEUED, GenerationJobStatus.RUNNING);

    private final GenerationJobRepository generationJobRepository;

    GenerationJobActivityGuard(GenerationJobRepository generationJobRepository) {
        this.generationJobRepository = generationJobRepository;
    }

    void guardDraft(Long draftId, Instant now) {
        reject(generationJobRepository.findByDraftIdAndStatusIn(draftId, ACTIVE_STATUSES), now);
    }

    /** 같은 뼈대에 OUTLINE 잡이 돌고 있으면 재생성·채우기를 막는다 — 두 잡이 스텝을 번갈아 갈아치우는 사고를 방지한다. */
    void guardOutline(Long outlineId, Instant now) {
        reject(generationJobRepository.findByOutlineIdAndStatusIn(outlineId, ACTIVE_STATUSES), now);
    }

    void guardOutlineStep(Long stepId, Instant now) {
        reject(generationJobRepository.findByOutlineStepIdAndStatusIn(stepId, ACTIVE_STATUSES), now);
    }

    /** 만료 판정만 필요한 조회 경로(getJobWithExpiry)가 재사용한다. */
    void expireIfNeeded(GenerationJob job, Instant now) {
        boolean queuedExpired = job.getStatus() == GenerationJobStatus.QUEUED
                && Duration.between(job.getCreatedAt(), now).compareTo(QUEUED_EXPIRY) > 0;
        boolean runningExpired = job.getStatus() == GenerationJobStatus.RUNNING
                && Duration.between(job.getStartedAt(), now).compareTo(RUNNING_EXPIRY) > 0;
        if (queuedExpired || runningExpired) {
            job.fail(null, EXPIRY_MESSAGE, now);
        }
    }

    private void reject(List<GenerationJob> activeJobs, Instant now) {
        activeJobs.forEach(job -> expireIfNeeded(job, now));
        if (activeJobs.stream().anyMatch(GenerationJob::isActive)) {
            throw new BusinessException(AuthoringErrorType.AUTHORING_DRAFT_JOB_ACTIVE);
        }
    }
}
