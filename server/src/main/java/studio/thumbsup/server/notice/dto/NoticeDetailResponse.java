package studio.thumbsup.server.notice.dto;

import java.time.OffsetDateTime;
import studio.thumbsup.server.common.time.TimeZones;
import studio.thumbsup.server.notice.Notice;

/** GET /api/v1/notices/{noticeId} 전용 응답 DTO — 목록과 모양이 비슷해도 공유하지 않는다 (WET > 성급한 DRY). */
public record NoticeDetailResponse(Long noticeId, String title, String content, OffsetDateTime createdAt) {

    public static NoticeDetailResponse from(Notice notice) {
        return new NoticeDetailResponse(
                notice.getId(),
                notice.getTitle(),
                notice.getContent(),
                notice.getCreatedAt().atZone(TimeZones.KST).toOffsetDateTime());
    }
}
