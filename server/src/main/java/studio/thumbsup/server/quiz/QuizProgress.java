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
 * 유저별 커리큘럼 진행 상태 — 스텝(5문제 세트) 단위로 진행도를 추적한다.
 * 유저당 한 행만 존재한다(DB 유니크 제약). {@code userId}는 다른 도메인 참조라 ID 값으로만 둔다.
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
    private int currentStepOrder;

    private QuizProgress(Long userId) {
        this.userId = userId;
        this.currentStepOrder = 1;
    }

    public static QuizProgress create(Long userId) {
        return new QuizProgress(userId);
    }

    public void advanceToNextStep() {
        this.currentStepOrder++;
    }
}
