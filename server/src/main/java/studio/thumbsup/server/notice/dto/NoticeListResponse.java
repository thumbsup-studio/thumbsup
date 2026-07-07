package studio.thumbsup.server.notice.dto;

import java.time.OffsetDateTime;
import java.util.List;
import studio.thumbsup.server.common.time.TimeZones;
import studio.thumbsup.server.notice.Notice;

/**
 * GET /api/v1/notices 전용 응답 DTO — 다른 API와 공유하지 않는다.
 * 리스트 키는 항상 {@code items} (docs/api-standard.md §4).
 */
public record NoticeListResponse(List<NoticeItem> items) {

    public static NoticeListResponse from(List<Notice> notices) {
        return new NoticeListResponse(notices.stream().map(NoticeItem::from).toList());
    }

    public record NoticeItem(Long noticeId, String title, OffsetDateTime createdAt) {

        private static NoticeItem from(Notice notice) {
            return new NoticeItem(
                    notice.getId(),
                    notice.getTitle(),
                    notice.getCreatedAt().atZone(TimeZones.KST).toOffsetDateTime()); // UTC 저장 → KST 직렬화
        }
    }
}
