package studio.thumbsup.server.notice;

import java.time.Instant;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 공지 테스트 픽스처 — feature 소유 (다른 feature와 공유하지 않는다).
 * 영속화 없이 id·감사 필드를 채워 단위테스트에서 사용한다.
 */
public final class NoticeFixture {

    public static final Instant CREATED_AT = Instant.parse("2026-07-07T00:00:00Z");

    public static Notice notice(Long id, String title) {
        Notice notice = Notice.create(title, title + " 내용");
        ReflectionTestUtils.setField(notice, "id", id);
        ReflectionTestUtils.setField(notice, "createdAt", CREATED_AT);
        ReflectionTestUtils.setField(notice, "updatedAt", CREATED_AT);
        return notice;
    }

    private NoticeFixture() {}
}
