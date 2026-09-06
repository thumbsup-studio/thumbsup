package studio.thumbsup.server.quiz.tag;

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
 * 유저가 특정 태그를 학습하는 데 관련된(완료한) 스텝(#233, #324) — 지식 그래프 상세 카드의
 * {@code relatedSteps} 조립용. 하나의 태그가 여러 완료 스텝에 걸쳐 나올 수 있어 {@link UserTag}와
 * 별도 테이블로 둔다. {@code userId}는 다른 도메인 참조라 ID 값으로만 둔다.
 *
 * <p>{@code UserTag}와 달리 멱등 보호가 필요 없다 — 같은 스텝을 두 번 완료 기록할 일이 없고, 경합
 * 승패와 무관하게 항상 독립적으로 insert된다({@code LearnedTagRecorder} Javadoc 참고).
 */
@Getter
@Entity
@Table(name = "user_tag_step")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserTagStep extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private Long tagId;

    /** 이 기록이 가리키는 스텝의 PK(#292) — step_order는 코스마다 겹칠 수 있어 식별에 쓰지 않는다. */
    @Column(nullable = false)
    private Long quizStepId;

    private UserTagStep(Long userId, Long tagId, Long quizStepId) {
        this.userId = userId;
        this.tagId = tagId;
        this.quizStepId = quizStepId;
    }

    public static UserTagStep create(Long userId, Long tagId, Long quizStepId) {
        return new UserTagStep(userId, tagId, quizStepId);
    }
}
