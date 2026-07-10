package studio.thumbsup.server.mascot;

import java.time.Instant;
import org.springframework.test.util.ReflectionTestUtils;

/** 보리(마스코트) 테스트 픽스처 — feature 소유 (다른 feature와 공유하지 않는다). */
public final class MascotFixture {

    public static Mascot mascot(Long id, Long userId, int fullnessAtLastFeed, Instant lastFedAt) {
        Mascot mascot = Mascot.create(userId, lastFedAt);
        ReflectionTestUtils.setField(mascot, "id", id);
        ReflectionTestUtils.setField(mascot, "fullnessAtLastFeed", fullnessAtLastFeed);
        ReflectionTestUtils.setField(mascot, "lastFedAt", lastFedAt);
        ReflectionTestUtils.setField(mascot, "createdAt", lastFedAt);
        ReflectionTestUtils.setField(mascot, "updatedAt", lastFedAt);
        return mascot;
    }

    private MascotFixture() {}
}
