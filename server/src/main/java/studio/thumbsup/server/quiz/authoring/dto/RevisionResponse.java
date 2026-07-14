package studio.thumbsup.server.quiz.authoring.dto;

import java.time.OffsetDateTime;
import studio.thumbsup.server.common.time.TimeZones;
import studio.thumbsup.server.quiz.authoring.QuizDraftRevision;

public record RevisionResponse(
        int revisionNo, String reviewSummary, Long reviewedBy, Long jobId, OffsetDateTime createdAt) {

    public static RevisionResponse from(QuizDraftRevision revision) {
        return new RevisionResponse(
                revision.getRevisionNo(),
                revision.getReviewSummary(),
                revision.getReviewedBy(),
                revision.getJobId(),
                revision.getCreatedAt().atZone(TimeZones.KST).toOffsetDateTime());
    }
}
