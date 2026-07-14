package studio.thumbsup.server.quiz.authoring.dto;

import java.time.OffsetDateTime;
import studio.thumbsup.server.common.time.TimeZones;
import studio.thumbsup.server.quiz.authoring.QuizDraft;

public record DraftSummaryResponse(
        Long draftId,
        String origin,
        String status,
        String topic,
        Long sourceQuizId,
        int revisionCount,
        OffsetDateTime updatedAt) {

    public static DraftSummaryResponse from(QuizDraft draft, int revisionCount) {
        return new DraftSummaryResponse(
                draft.getId(),
                draft.getOrigin().name(),
                draft.getStatus().name(),
                draft.getTopic(),
                draft.getSourceQuizId(),
                revisionCount,
                draft.getUpdatedAt().atZone(TimeZones.KST).toOffsetDateTime());
    }
}
