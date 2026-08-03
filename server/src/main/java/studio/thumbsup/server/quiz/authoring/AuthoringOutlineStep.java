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

/** 뼈대 안의 학습 스텝. draft와 라이브 문제는 ID로만 참조한다. */
@Getter
@Entity
@Table(name = "authoring_outline_step")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AuthoringOutlineStep extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long outlineId;

    @Column(nullable = false)
    private int orderNo;

    @Column(nullable = false, length = 200)
    private String topic;

    @Column(length = 500)
    private String learningGoal;

    private Long draftId;

    private AuthoringOutlineStep(Long outlineId, int orderNo, String topic, String learningGoal) {
        this.outlineId = outlineId;
        this.orderNo = orderNo;
        this.topic = topic;
        this.learningGoal = learningGoal;
    }

    public static AuthoringOutlineStep create(Long outlineId, int orderNo, String topic, String learningGoal) {
        return new AuthoringOutlineStep(outlineId, orderNo, topic, learningGoal);
    }

    public void changeTopic(String topic) {
        this.topic = topic;
    }

    public void changeOrderNo(int orderNo) {
        this.orderNo = orderNo;
    }

    public void attachDraft(Long draftId) {
        this.draftId = draftId;
    }
}
