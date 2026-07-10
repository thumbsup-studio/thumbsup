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
 * 유저의 게이미피케이션 상태(스트릭·포인트) — 유저당 1행(DB unique). {@code userId}는 다른 도메인(auth)의
 * 참조라 연관관계가 아니라 ID 값으로만 둔다(server/docs/dto-and-query-patterns.md #2).
 *
 * <p>"지금 어느 스텝까지 왔는지"는 {@link QuizProgress#getCurrentStepOrder()}가 유일한 소스다(#117) —
 * 예전엔 이 엔티티가 {@code cursorUnitIndex}/{@code courseId}로 화면 커서를 따로 들고 있었으나, 두 진행
 * 상태가 따로 갱신되며 어긋나는 문제가 있어 제거했다.
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
    private int streak;

    @Column(nullable = false)
    private int points;

    private UserProgress(Long userId, int streak, int points) {
        this.userId = userId;
        this.streak = streak;
        this.points = points;
    }

    public static UserProgress create(Long userId, int streak, int points) {
        return new UserProgress(userId, streak, points);
    }
}
