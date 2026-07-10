package studio.thumbsup.server.mascot;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Duration;
import java.time.Instant;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/**
 * 홈 캐릭터 '보리' 포만감 상태 — 유저당 한 행(#35).
 *
 * <p>포만감은 배치·스케줄러 없이 조회 시점마다 다시 계산하는 파생값이다. 마지막으로 먹인 시점
 * ({@link #lastFedAt})과 그때 값({@link #fullnessAtLastFeed})만 저장해두고, 현재값은
 * {@link #getCurrentFullness}가 경과일수만큼 하루 {@value #DECAY_PER_DAY}%씩 감소시켜 즉시 계산한다.
 */
@Getter
@Entity
@Table(name = "mascot")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Mascot extends BaseEntity {

    public static final int MAX_FULLNESS = 100;
    public static final int MIN_FULLNESS = 0;
    private static final int DECAY_PER_DAY = 10;
    private static final int FEED_AMOUNT = 20;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
    private Long userId;

    @Column(nullable = false)
    private int fullnessAtLastFeed;

    @Column(nullable = false)
    private Instant lastFedAt;

    private Mascot(Long userId, Instant now) {
        this.userId = userId;
        this.fullnessAtLastFeed = MAX_FULLNESS;
        this.lastFedAt = now;
    }

    /** 신규 유저는 배부른 상태(100%)로 시작한다. */
    public static Mascot create(Long userId, Instant now) {
        return new Mascot(userId, now);
    }

    /** 마지막으로 먹인 시점 이후 경과일수만큼 감소시킨 현재 포만감. */
    public int getCurrentFullness(Instant now) {
        long daysElapsed = Duration.between(lastFedAt, now).toDays();
        return clamp(fullnessAtLastFeed - (int) (daysElapsed * DECAY_PER_DAY));
    }

    /** 현재(감소 반영) 포만감에 고정치를 더해 갱신한다 — 세션(퀴즈 5문제) 완료 시 프론트가 호출. */
    public void feed(Instant now) {
        this.fullnessAtLastFeed = clamp(getCurrentFullness(now) + FEED_AMOUNT);
        this.lastFedAt = now;
    }

    private int clamp(int value) {
        return Math.max(MIN_FULLNESS, Math.min(MAX_FULLNESS, value));
    }
}
