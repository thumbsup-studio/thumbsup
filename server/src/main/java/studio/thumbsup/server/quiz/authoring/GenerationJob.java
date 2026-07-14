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
 * 로컬 브리지가 폴링·실행하는 생성/검수 잡 — 큐 테이블을 겸한다({@code pickNextQueued}가
 * {@code FOR UPDATE SKIP LOCKED}로 동시 폴링을 안전하게 처리한다).
 *
 * <p>{@code GENERATE}는 {@link #topic}만, {@code REVIEW}는 {@link #draftId}·{@link #feedback}만
 * 채워진다 — 종류별로 static factory를 분리해 이 조합을 강제한다.
 */
@Getter
@Entity
@Table(name = "generation_job")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class GenerationJob extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private GenerationJobKind kind;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private GenerationJobStatus status;

    @Column(nullable = false)
    private Long assigneeUserId;

    @Enumerated(EnumType.STRING)
    @Column(length = 10)
    private BridgeCli cli;

    private Long draftId;

    private String topic;

    @Column(columnDefinition = "TEXT")
    private String feedback;

    @Column(nullable = false, columnDefinition = "MEDIUMTEXT")
    private String prompt;

    @Column(columnDefinition = "TEXT")
    private String error;

    private Instant startedAt;

    private Instant finishedAt;

    private GenerationJob(
            GenerationJobKind kind, Long assigneeUserId, Long draftId, String topic, String feedback, String prompt) {
        this.kind = kind;
        this.status = GenerationJobStatus.QUEUED;
        this.assigneeUserId = assigneeUserId;
        this.draftId = draftId;
        this.topic = topic;
        this.feedback = feedback;
        this.prompt = prompt;
    }

    public static GenerationJob createGenerate(Long assigneeUserId, String topic, String prompt) {
        return new GenerationJob(GenerationJobKind.GENERATE, assigneeUserId, null, topic, null, prompt);
    }

    public static GenerationJob createReview(Long assigneeUserId, Long draftId, String feedback, String prompt) {
        return new GenerationJob(GenerationJobKind.REVIEW, assigneeUserId, draftId, null, feedback, prompt);
    }

    public void markRunning(Instant now) {
        this.status = GenerationJobStatus.RUNNING;
        this.startedAt = now;
    }

    public void succeed(BridgeCli cli, Instant now) {
        this.status = GenerationJobStatus.SUCCEEDED;
        this.cli = cli;
        this.finishedAt = now;
    }

    public void fail(BridgeCli cli, String error, Instant now) {
        this.status = GenerationJobStatus.FAILED;
        this.cli = cli;
        this.error = error;
        this.finishedAt = now;
    }

    public void attachDraft(Long draftId) {
        this.draftId = draftId;
    }

    public boolean isActive() {
        return status == GenerationJobStatus.QUEUED || status == GenerationJobStatus.RUNNING;
    }
}
