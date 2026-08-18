package studio.thumbsup.server.quiz.concept;

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
 * 유저가 특정 개념을 학습하는 데 관련된(완료한) 스텝(#233) — 지식 그래프 상세 카드의
 * {@code relatedSteps} 조립용. 하나의 개념이 여러 완료 스텝에 걸쳐 나올 수 있어 {@link UserConcept}와
 * 별도 테이블로 둔다. {@code userId}는 다른 도메인 참조라 ID 값으로만 둔다.
 */
@Getter
@Entity
@Table(name = "user_concept_step")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserConceptStep extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private Long conceptId;

    /** 이 기록이 가리키는 스텝의 PK(#292) — step_order는 코스마다 겹칠 수 있어 식별에 쓰지 않는다. */
    @Column(nullable = false)
    private Long quizStepId;

    private UserConceptStep(Long userId, Long conceptId, Long quizStepId) {
        this.userId = userId;
        this.conceptId = conceptId;
        this.quizStepId = quizStepId;
    }

    public static UserConceptStep create(Long userId, Long conceptId, Long quizStepId) {
        return new UserConceptStep(userId, conceptId, quizStepId);
    }
}
