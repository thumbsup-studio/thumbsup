package studio.thumbsup.server.quiz;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import java.util.ArrayList;
import java.util.List;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/** 스텝 하나를 시작하기 전에 읽는 짧은 개념 브리핑 aggregate root. */
@Getter
@Entity
@Table(name = "quiz_step_briefing")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizStepBriefing extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** {@link QuizStep}의 영구 식별자. 표시 순서(stepOrder)와 분리해 연결한다. */
    @Column(nullable = false, unique = true)
    private Long quizStepId;

    @Column(nullable = false, length = 500)
    private String summary;

    @OneToMany(mappedBy = "briefing", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("displayOrder ASC")
    private List<QuizStepBriefingBlock> blocks = new ArrayList<>();

    private QuizStepBriefing(Long quizStepId, String summary) {
        this.quizStepId = quizStepId;
        this.summary = summary;
    }

    public static QuizStepBriefing create(Long quizStepId, String summary) {
        return new QuizStepBriefing(quizStepId, summary);
    }

    public void addBlock(QuizStepBriefingBlockType type, String heading, String content, int displayOrder) {
        blocks.add(QuizStepBriefingBlock.create(this, type, heading, content, displayOrder));
    }
}
