package studio.thumbsup.server.common.user;

/**
 * 화면 표시용 유저 진행 상태 스냅샷 — {@code user} 도메인의 {@code UserProgress} 엔티티를 그대로
 * 노출하지 않기 위한 크로스 슬라이스 조회 결과물. {@code streak}은 이미 "화면 표시용 유효 스트릭"
 * 계산이 끝난 값이다({@code UserProgress#getEffectiveStreak}).
 */
public record UserProgressSnapshot(int streak, int points, boolean todayCompleted) {

    public static UserProgressSnapshot empty() {
        return new UserProgressSnapshot(0, 0, false);
    }
}
