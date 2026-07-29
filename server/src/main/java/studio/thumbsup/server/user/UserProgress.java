package studio.thumbsup.server.user;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDate;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/**
 * 유저의 게이미피케이션 상태(스트릭·포인트) — 유저당 1행(DB unique). {@code userId}는 다른 도메인(auth)의
 * 참조라 연관관계가 아니라 ID 값으로만 둔다(server/docs/dto-and-query-patterns.md #2).
 *
 * <p>"지금 어느 스텝까지 왔는지"는 {@code studio.thumbsup.server.quiz.QuizProgress#getCurrentStepOrder()}가 유일한 소스다(#117) —
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

    private LocalDate lastCompletedDate;

    private UserProgress(Long userId, int streak, int points) {
        this.userId = userId;
        this.streak = streak;
        this.points = points;
    }

    public static UserProgress create(Long userId, int streak, int points) {
        return new UserProgress(userId, streak, points);
    }

    /**
     * 오늘의 학습(1스텝)을 처음 완료했을 때 호출한다. 같은 날 두 번 불려도 안전(멱등) — 스트릭이
     * 두 번 오르지 않는다. 어제까지 이어졌으면 +1, 하루라도 건너뛰었으면 1로 리셋한다.
     */
    public void recordCompletion(LocalDate today) {
        if (lastCompletedDate != null && today.isBefore(lastCompletedDate)) {
            return;
        }
        if (today.equals(lastCompletedDate)) {
            return;
        }
        boolean continuedFromYesterday = lastCompletedDate != null && lastCompletedDate.equals(today.minusDays(1));
        streak = continuedFromYesterday ? streak + 1 : 1;
        lastCompletedDate = today;
    }

    /**
     * 화면 표시용 스트릭. DB는 건드리지 않는다 — "끊긴 상태"를 저장하지 않고 조회 시점에 계산해서
     * 이틀 이상 건너뛰었으면 0으로 보여준다.
     */
    public int getEffectiveStreak(LocalDate today) {
        if (lastCompletedDate == null || lastCompletedDate.isBefore(today.minusDays(1))) {
            return 0;
        }
        return streak;
    }
}
