package studio.thumbsup.server.quiz;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/** {@link QuizStepBriefing} 안에서 순서대로 노출되는 하나의 설명 블록. */
@Getter
@Entity
@Table(name = "quiz_step_briefing_block")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizStepBriefingBlock extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "briefing_id", nullable = false)
    private QuizStepBriefing briefing;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private QuizStepBriefingBlockType type;

    @Column(nullable = false, length = 100)
    private String heading;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(nullable = false)
    private int displayOrder;

    private QuizStepBriefingBlock(
            QuizStepBriefing briefing,
            QuizStepBriefingBlockType type,
            String heading,
            String content,
            int displayOrder) {
        this.briefing = briefing;
        this.type = type;
        this.heading = heading;
        this.content = content;
        this.displayOrder = displayOrder;
    }

    static QuizStepBriefingBlock create(
            QuizStepBriefing briefing,
            QuizStepBriefingBlockType type,
            String heading,
            String content,
            int displayOrder) {
        return new QuizStepBriefingBlock(briefing, type, heading, content, displayOrder);
    }
}
