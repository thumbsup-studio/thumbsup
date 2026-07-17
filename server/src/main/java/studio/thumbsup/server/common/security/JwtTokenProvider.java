package studio.thumbsup.server.common.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import javax.crypto.SecretKey;
import org.springframework.stereotype.Component;
import org.springframework.util.Assert;

@Component
public class JwtTokenProvider {

    private static final int REFRESH_TOKEN_BYTE_LENGTH = 32;
    private static final String ROLE_CLAIM = "role";
    /** role 클레임 없이 발급된(과거) 토큰이거나 클레임이 비어 있을 때의 안전한 기본값. */
    private static final String DEFAULT_ROLE = "USER";

    private final SecretKey secretKey;
    private final Duration accessTokenValidity;
    private final Clock clock;
    private final SecureRandom secureRandom = new SecureRandom();

    public JwtTokenProvider(JwtProperties properties, Clock clock) {
        Assert.hasText(properties.secret(), "thumbsup.jwt.secret 설정이 필요합니다 (fail-fast)");
        Assert.notNull(properties.accessTokenValidity(), "thumbsup.jwt.access-token-validity 설정이 필요합니다");
        this.secretKey = Keys.hmacShaKeyFor(properties.secret().getBytes(StandardCharsets.UTF_8));
        this.accessTokenValidity = properties.accessTokenValidity();
        this.clock = clock;
    }

    /** role 없이 발급 — USER로 간주된다. 저작(#174) 등 ADMIN이 필요한 경로는 {@link #createAccessToken(Long, String)}을 쓴다. */
    public String createAccessToken(Long userId) {
        return createAccessToken(userId, DEFAULT_ROLE);
    }

    public String createAccessToken(Long userId, String role) {
        Instant now = clock.instant();
        return Jwts.builder()
                .subject(String.valueOf(userId))
                .claim(ROLE_CLAIM, role)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(accessTokenValidity)))
                .signWith(secretKey)
                .compact();
    }

    public String createRefreshToken() {
        byte[] bytes = new byte[REFRESH_TOKEN_BYTE_LENGTH];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    /**
     * 토큰에서 userId를 추출한다.
     *
     * @throws ExpiredJwtException 만료된 토큰 (→ TOKEN_EXPIRED)
     * @throws JwtException 서명 불일치 등 무효 토큰 (→ UNAUTHORIZED)
     */
    public Long parseUserId(String token) {
        return parseClaims(token).userId();
    }

    /**
     * userId·role을 한 번의 서명 검증으로 함께 추출한다 — {@link JwtAuthenticationFilter}가 SecurityContext에
     * 권한(GrantedAuthority)까지 싣기 위해 쓴다.
     *
     * @throws ExpiredJwtException 만료된 토큰 (→ TOKEN_EXPIRED)
     * @throws JwtException 서명 불일치 등 무효 토큰 (→ UNAUTHORIZED)
     */
    public AccessTokenClaims parseClaims(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(secretKey)
                .clock(() -> Date.from(clock.instant()))
                .build()
                .parseSignedClaims(token)
                .getPayload();
        Long userId = Long.parseLong(claims.getSubject());
        String role = claims.get(ROLE_CLAIM, String.class);
        return new AccessTokenClaims(userId, role == null ? DEFAULT_ROLE : role);
    }

    public record AccessTokenClaims(Long userId, String role) {}
}
