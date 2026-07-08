package studio.thumbsup.server.auth;

import java.time.Instant;
import org.springframework.test.util.ReflectionTestUtils;

/** auth 테스트 픽스처 — feature 소유. 영속화 없이 id·감사 필드를 채워 단위테스트에서 사용한다. */
public final class AuthFixture {

    public static final Instant CREATED_AT = Instant.parse("2026-07-07T00:00:00Z");

    public static User user(Long id, String email, String password) {
        User user = User.create(email, password);
        ReflectionTestUtils.setField(user, "id", id);
        ReflectionTestUtils.setField(user, "createdAt", CREATED_AT);
        ReflectionTestUtils.setField(user, "updatedAt", CREATED_AT);
        return user;
    }

    public static RefreshToken refreshToken(Long id, Long userId, String tokenHash, Instant expiresAt) {
        RefreshToken token = RefreshToken.create(userId, tokenHash, expiresAt);
        ReflectionTestUtils.setField(token, "id", id);
        ReflectionTestUtils.setField(token, "createdAt", CREATED_AT);
        ReflectionTestUtils.setField(token, "updatedAt", CREATED_AT);
        return token;
    }

    private AuthFixture() {}
}
