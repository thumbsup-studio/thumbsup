package studio.thumbsup.server.quiz.authoring.dto;

import com.fasterxml.jackson.databind.JsonNode;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import studio.thumbsup.server.common.time.TimeZones;
import studio.thumbsup.server.quiz.authoring.QuizDraft;
import studio.thumbsup.server.quiz.authoring.QuizDraftRevision;

/** {@link DraftSummaryResponse}의 필드를 전부 포함하고 상세 정보를 덧붙인다 — 계약상 별도 DTO(WET > 성급한 DRY). */
public record DraftDetailResponse(
        Long draftId,
        String origin,
        String status,
        String topic,
        Long sourceQuizId,
        int revisionCount,
        OffsetDateTime updatedAt,
        JsonNode payload,
        List<RevisionResponse> revisions,
        Long createdBy,
        Long approvedBy,
        OffsetDateTime approvedAt) {

    public static DraftDetailResponse from(QuizDraft draft, JsonNode payload, List<QuizDraftRevision> revisions) {
        return new DraftDetailResponse(
                draft.getId(),
                draft.getOrigin().name(),
                draft.getStatus().name(),
                draft.getTopic(),
                draft.getSourceQuizId(),
                revisions.size(),
                toKst(draft.getUpdatedAt()),
                payload,
                revisions.stream().map(RevisionResponse::from).toList(),
                draft.getCreatedBy(),
                draft.getApprovedBy(),
                toKst(draft.getApprovedAt()));
    }

    private static OffsetDateTime toKst(Instant instant) {
        return instant == null ? null : instant.atZone(TimeZones.KST).toOffsetDateTime();
    }
}
