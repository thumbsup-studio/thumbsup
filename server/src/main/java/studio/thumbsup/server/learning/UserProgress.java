package studio.thumbsup.server.learning;

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
 * 유저의 코스별 학습 진행 상태 — 다음에 풀 화(커서), 스트릭, 포인트를 담는다.
 * 유저+코스당 1행(DB unique). {@code userId}는 다른 도메인(auth)의 참조라 연관관계가 아니라 ID 값으로만
 * 둔다(server/docs/dto-and-query-patterns.md #2). {@code courseId}는 같은 피처지만 유저당 코스별로
 * 1행만 존재해 굳이 연관관계를 맺지 않고 ID로 참조한다.
 *
 * <p>⚠️ {@code quiz.QuizProgress}(커리큘럼 스텝 진행)와는 별개의 개념이다 — 이 엔티티는 홈 화면 표시
 * 전용이며, 테이블명도 {@code user_progress}로 {@code quiz_progress}와 구분한다.
 *
 * <p>이 PR은 조회만 다룬다 — streak/points 증가(쓰기) 로직은 후속 티켓의 몫이라 이 엔티티는 시드 데이터로만
 * 채워진다({@code create}는 테스트·시드 조립용).
 */
@Getter
@Entity
@Table(name = "user_progress")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserProgress extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private Long courseId;

    @Column(nullable = false)
    private int cursorUnitIndex;

    @Column(nullable = false)
    private int streak;

    @Column(nullable = false)
    private int points;

    private UserProgress(Long userId, Long courseId, int cursorUnitIndex, int streak, int points) {
        this.userId = userId;
        this.courseId = courseId;
        this.cursorUnitIndex = cursorUnitIndex;
        this.streak = streak;
        this.points = points;
    }

    public static UserProgress create(Long userId, Long courseId, int cursorUnitIndex, int streak, int points) {
        return new UserProgress(userId, courseId, cursorUnitIndex, streak, points);
    }
}
