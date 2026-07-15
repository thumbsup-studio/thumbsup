package studio.thumbsup.server.common.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

/**
 * 시간 의존 로직을 고정 Clock으로 결정적으로 검증한다 — sleep 없이 만료를 테스트한다.
 */
class JwtTokenProviderTest {

    private static final String SECRET = "test-secret-key-for-jwt-hmac-sha-256-minimum-32-bytes";
    private static final Instant BASE_TIME = Instant.parse("2026-07-07T00:00:00Z");
    private static final Duration VALIDITY = Duration.ofMinutes(30);
    private static final Duration REFRESH_VALIDITY = Duration.ofDays(14);

    private JwtTokenProvider providerAt(Instant instant) {
        return new JwtTokenProvider(
                new JwtProperties(SECRET, VALIDITY, REFRESH_VALIDITY), Clock.fixed(instant, ZoneOffset.UTC));
    }

    @Test
    void 발급한_토큰에서_userId를_복원한다() {
        JwtTokenProvider provider = providerAt(BASE_TIME);

        String token = provider.createAccessToken(42L);

        assertThat(provider.parseUserId(token)).isEqualTo(42L);
    }

    @Test
    void role_없이_발급하면_USER로_간주된다() {
        JwtTokenProvider provider = providerAt(BASE_TIME);

        String token = provider.createAccessToken(42L);

        JwtTokenProvider.AccessTokenClaims claims = provider.parseClaims(token);
        assertThat(claims.userId()).isEqualTo(42L);
        assertThat(claims.role()).isEqualTo("USER");
    }

    @Test
    void role을_지정해_발급하면_그대로_복원된다() {
        JwtTokenProvider provider = providerAt(BASE_TIME);

        String token = provider.createAccessToken(42L, "ADMIN");

        assertThat(provider.parseClaims(token).role()).isEqualTo("ADMIN");
    }

    @Test
    void 유효기간_내에서는_시간이_지나도_검증된다() {
        String token = providerAt(BASE_TIME).createAccessToken(42L);

        JwtTokenProvider after29Minutes = providerAt(BASE_TIME.plus(Duration.ofMinutes(29)));

        assertThat(after29Minutes.parseUserId(token)).isEqualTo(42L);
    }

    @Test
    void 유효기간이_지난_토큰은_ExpiredJwtException을_던진다() {
        String token = providerAt(BASE_TIME).createAccessToken(42L);

        JwtTokenProvider after31Minutes = providerAt(BASE_TIME.plus(Duration.ofMinutes(31)));

        assertThatThrownBy(() -> after31Minutes.parseUserId(token)).isInstanceOf(ExpiredJwtException.class);
    }

    @Test
    void 서명이_다른_토큰은_JwtException을_던진다() {
        JwtTokenProvider otherKeyProvider = new JwtTokenProvider(
                new JwtProperties("another-secret-key-for-jwt-hmac-sha-256-32bytes!!", VALIDITY, REFRESH_VALIDITY),
                Clock.fixed(BASE_TIME, ZoneOffset.UTC));
        String token = otherKeyProvider.createAccessToken(42L);

        assertThatThrownBy(() -> providerAt(BASE_TIME).parseUserId(token)).isInstanceOf(JwtException.class);
    }

    @Test
    void refresh_token은_매번_다른_고엔트로피_문자열을_생성한다() {
        JwtTokenProvider provider = providerAt(BASE_TIME);

        String first = provider.createRefreshToken();
        String second = provider.createRefreshToken();

        assertThat(first).isNotBlank();
        assertThat(second).isNotBlank();
        assertThat(first).isNotEqualTo(second);
    }
}
