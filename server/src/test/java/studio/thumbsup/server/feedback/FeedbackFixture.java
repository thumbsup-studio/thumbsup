package studio.thumbsup.server.feedback;

import java.time.Instant;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 의견 보내기 테스트 픽스처 — feature 소유 (다른 feature와 공유하지 않는다).
 * 영속화 없이 id·감사 필드를 채워 단위테스트에서 사용한다.
 */
public final class FeedbackFixture {

    public static final Instant CREATED_AT = Instant.parse("2026-07-07T00:00:00Z");

    public static Feedback feedback(Long id, Long userId, String content) {
        Feedback feedback = Feedback.create(userId, content);
        ReflectionTestUtils.setField(feedback, "id", id);
        ReflectionTestUtils.setField(feedback, "createdAt", CREATED_AT);
        ReflectionTestUtils.setField(feedback, "updatedAt", CREATED_AT);
        return feedback;
    }

    private FeedbackFixture() {}
}
