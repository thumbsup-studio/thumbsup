package studio.thumbsup.server.quiz;

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
 * 유저별 커리큘럼 진행 상태 — 코스마다 스텝(5문제 세트) 단위로 진행도를 독립적으로 추적한다.
 * 유저·코스 조합당 한 행만 존재한다(DB 유니크 제약). {@code userId}는 다른 도메인 참조라 ID 값으로만 둔다.
 * {@code courseId}도 같은 이유로 ID 값으로만 둔다 — {@link QuizStep}처럼 DB FK만 있고 JPA 연관관계는 없다.
 */
@Getter
@Entity
@Table(name = "quiz_progress")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizProgress extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private Long courseId;

    @Column(nullable = false)
    private int currentStepOrder;

    private QuizProgress(Long userId, Long courseId, int initialStepOrder) {
        this.userId = userId;
        this.courseId = courseId;
        this.currentStepOrder = initialStepOrder;
    }

    /**
     * {@code initialStepOrder}는 호출자(Service)가 넘긴다 — stepOrder가 코스 무관 전역 순번이라
     * "이 코스의 시작 스텝"을 엔티티 스스로는 알 수 없다({@link QuizStepRepository#findMinStepOrderByCourseId}).
     */
    public static QuizProgress create(Long userId, Long courseId, int initialStepOrder) {
        return new QuizProgress(userId, courseId, initialStepOrder);
    }

    public void advanceToNextStep() {
        this.currentStepOrder++;
    }
}
