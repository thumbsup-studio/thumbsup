package studio.thumbsup.server.quiz.authoring;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/**
 * draft의 리비전 이력 — 검수/개선 잡이 끝날 때마다 한 건씩 쌓인다.
 * {@code (draftId, revisionNo)}가 unique라 같은 회차를 두 번 기록할 수 없다.
 */
@Getter
@Entity
@Table(name = "quiz_draft_revision")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizDraftRevision extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long draftId;

    @Column(nullable = false)
    private int revisionNo;

    @Column(nullable = false, columnDefinition = "MEDIUMTEXT")
    private String payload;

    @Column(columnDefinition = "TEXT")
    private String reviewSummary;

    private Long reviewedBy;

    @Column(nullable = false)
    private Long jobId;

    private QuizDraftRevision(
            Long draftId, int revisionNo, String payload, String reviewSummary, Long reviewedBy, Long jobId) {
        this.draftId = draftId;
        this.revisionNo = revisionNo;
        this.payload = payload;
        this.reviewSummary = reviewSummary;
        this.reviewedBy = reviewedBy;
        this.jobId = jobId;
    }

    public static QuizDraftRevision create(
            Long draftId, int revisionNo, String payload, String reviewSummary, Long reviewedBy, Long jobId) {
        return new QuizDraftRevision(draftId, revisionNo, payload, reviewSummary, reviewedBy, jobId);
    }
}
