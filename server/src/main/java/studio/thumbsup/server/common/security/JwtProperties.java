package studio.thumbsup.server.common.security;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * JWT 설정 — application.yml의 {@code thumbsup.jwt.*}.
 *
 * <p>secret은 환경별 주입(local=application-local.yml, prod=SSM ${JWT_SECRET})이며
 * default 값을 두지 않는다 (fail-fast — server/docs/env-guide.md).
 */
@ConfigurationProperties(prefix = "thumbsup.jwt")
public record JwtProperties(String secret, Duration accessTokenValidity) {}
