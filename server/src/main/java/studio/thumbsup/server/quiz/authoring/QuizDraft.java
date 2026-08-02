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
import studio.thumbsup.server.quiz.generation.QuizPreset;

/**
 * 승인 전 스테이징 영역의 문제 세트 draft — 일반 draft는 승인되면 {@code Quiz}로 승격되고,
 * {@code OUTLINE_STEP} draft는 뼈대 발행 시점까지 스테이징에 남는다.
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
    @Column(nullable = false, length = 20)
    private QuizDraftOrigin origin;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private QuizDraftStatus status;

    @Column(nullable = false)
    private String topic;

    private Long sourceQuizId;

    @Column(nullable = false, columnDefinition = "MEDIUMTEXT")
    private String currentPayload;

    @Enumerated(EnumType.STRING)
    @Column(length = 10)
    private QuizPreset preset;

    @Column(nullable = false)
    private Long createdBy;

    private Long approvedBy;

    private Instant approvedAt;

    private QuizDraft(
            QuizDraftOrigin origin,
            String topic,
            Long sourceQuizId,
            String currentPayload,
            QuizPreset preset,
            Long createdBy) {
        this.origin = origin;
        this.status = QuizDraftStatus.DRAFT;
        this.topic = topic;
        this.sourceQuizId = sourceQuizId;
        this.currentPayload = currentPayload;
        this.preset = preset;
        this.createdBy = createdBy;
    }

    public static QuizDraft createNew(String topic, String payloadJson, Long createdBy) {
        return new QuizDraft(QuizDraftOrigin.NEW, topic, null, payloadJson, null, createdBy);
    }

    public static QuizDraft createImprove(String topic, Long sourceQuizId, String payloadJson, Long createdBy) {
        return new QuizDraft(QuizDraftOrigin.IMPROVE, topic, sourceQuizId, payloadJson, null, createdBy);
    }

    public static QuizDraft createForOutlineStep(String topic, String payloadJson, QuizPreset preset, Long createdBy) {
        return new QuizDraft(QuizDraftOrigin.OUTLINE_STEP, topic, null, payloadJson, preset, createdBy);
    }

    /** 배포 전 생성된 draft는 preset 컬럼이 NULL이다 — 그 시절 유일한 구성이던 BASIC_5로 해석한다. */
    public QuizPreset getPreset() {
        return preset == null ? QuizPreset.BASIC_5 : preset;
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
