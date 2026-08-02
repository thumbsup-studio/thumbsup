package studio.thumbsup.server.quiz.authoring.dto;

import java.time.Instant;
import java.time.OffsetDateTime;
import studio.thumbsup.server.common.time.TimeZones;
import studio.thumbsup.server.quiz.authoring.GenerationJob;

public record JobStatusResponse(
        Long jobId,
        String kind,
        String status,
        Long draftId,
        String error,
        OffsetDateTime createdAt,
        OffsetDateTime startedAt,
        OffsetDateTime finishedAt,
        Long outlineId,
        Long outlineStepId) {

    public static JobStatusResponse from(GenerationJob job) {
        return new JobStatusResponse(
                job.getId(),
                job.getKind().name(),
                job.getStatus().name(),
                job.getDraftId(),
                job.getError(),
                toKst(job.getCreatedAt()),
                toKst(job.getStartedAt()),
                toKst(job.getFinishedAt()),
                job.getOutlineId(),
                job.getOutlineStepId());
    }

    private static OffsetDateTime toKst(Instant instant) {
        return instant == null ? null : instant.atZone(TimeZones.KST).toOffsetDateTime();
    }
}
