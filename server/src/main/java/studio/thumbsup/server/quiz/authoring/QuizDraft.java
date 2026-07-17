package studio.thumbsup.server.quiz.authoring;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/**
 * 승인 전 스테이징 영역의 문제 세트 draft — 승인되면 {@code Quiz}로 승격된다(#174 T6).
 *
 * <p>{@link #sourceQuizId}는 다른 도메인(quiz)의 참조라 연관관계가 아니라 ID 값으로만 둔다
 * (server/docs/dto-and-query-patterns.md #2). {@code NEW} draft는 null, {@code IMPROVE} draft만 채워진다.
 */
@Getter
@Entity
@Table(name = "quiz_draft")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizDraft extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private QuizDraftOrigin origin;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private QuizDraftStatus status;

    @Column(nullable = false)
    private String topic;

    private Long sourceQuizId;

    @Column(nullable = false, columnDefinition = "MEDIUMTEXT")
    private String currentPayload;

    @Column(nullable = false)
    private Long createdBy;

    private Long approvedBy;

    private Instant approvedAt;

    private QuizDraft(QuizDraftOrigin origin, String topic, Long sourceQuizId, String currentPayload, Long createdBy) {
        this.origin = origin;
        this.status = QuizDraftStatus.DRAFT;
        this.topic = topic;
        this.sourceQuizId = sourceQuizId;
        this.currentPayload = currentPayload;
        this.createdBy = createdBy;
    }

    public static QuizDraft createNew(String topic, String payloadJson, Long createdBy) {
        return new QuizDraft(QuizDraftOrigin.NEW, topic, null, payloadJson, createdBy);
    }

    public static QuizDraft createImprove(String topic, Long sourceQuizId, String payloadJson, Long createdBy) {
        return new QuizDraft(QuizDraftOrigin.IMPROVE, topic, sourceQuizId, payloadJson, createdBy);
    }

    public void applyRevision(String payloadJson) {
        this.currentPayload = payloadJson;
    }

    /** 이미 APPROVED여도 여기서 막지 않는다 — 중복 승인 방지는 서비스 레이어의 몫이다. */
    public void approve(Long userId, Instant now) {
        this.status = QuizDraftStatus.APPROVED;
        this.approvedBy = userId;
        this.approvedAt = now;
    }
}
