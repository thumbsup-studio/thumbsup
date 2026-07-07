package studio.thumbsup.server.common.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import javax.crypto.SecretKey;
import org.springframework.stereotype.Component;
import org.springframework.util.Assert;

/**
 * Access token 발급·검증. 시간은 주입받은 {@link Clock}만 사용한다 (결정적 테스트).
 *
 * <p>Refresh token은 auth feature에서 DB 저장+회전으로 관리한다 — docs/api-standard.md §8.
 */
@Component
public class JwtTokenProvider {

    private final SecretKey secretKey;
    private final Duration accessTokenValidity;
    private final Clock clock;

    public JwtTokenProvider(JwtProperties properties, Clock clock) {
        Assert.hasText(properties.secret(), "thumbsup.jwt.secret 설정이 필요합니다 (fail-fast)");
        Assert.notNull(properties.accessTokenValidity(), "thumbsup.jwt.access-token-validity 설정이 필요합니다");
        this.secretKey = Keys.hmacShaKeyFor(properties.secret().getBytes(StandardCharsets.UTF_8));
        this.accessTokenValidity = properties.accessTokenValidity();
        this.clock = clock;
    }

    public String createAccessToken(Long userId) {
        Instant now = clock.instant();
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(accessTokenValidity)))
                .signWith(secretKey)
                .compact();
    }

    /**
     * 토큰에서 userId를 추출한다.
     *
     * @throws ExpiredJwtException 만료된 토큰 (→ TOKEN_EXPIRED)
     * @throws JwtException 서명 불일치 등 무효 토큰 (→ UNAUTHORIZED)
     */
    public Long parseUserId(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(secretKey)
                .clock(() -> Date.from(clock.instant()))
                .build()
                .parseSignedClaims(token)
                .getPayload();
        return Long.parseLong(claims.getSubject());
    }
}
