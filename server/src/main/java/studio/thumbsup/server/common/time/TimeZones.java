package studio.thumbsup.server.common.time;

import java.time.ZoneId;

/**
 * 시간대 상수 — 저장은 UTC(Instant), API 직렬화만 KST(+09:00). 계약: docs/api-standard.md §5.
 *
 * <p>DTO에서 {@code instant.atZone(TimeZones.KST).toOffsetDateTime()} 형태로 변환한다.
 */
public final class TimeZones {

    public static final ZoneId KST = ZoneId.of("Asia/Seoul");

    private TimeZones() {}
}
