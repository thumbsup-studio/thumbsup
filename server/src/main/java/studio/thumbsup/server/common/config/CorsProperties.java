package studio.thumbsup.server.common.config;

import jakarta.validation.constraints.NotEmpty;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * CORS 허용 origin pattern — 프로파일별 주입 (local=application-local.yml,
 * prod=SSM ${CORS_ALLOWED_ORIGIN_PATTERNS}).
 * default 없음 (fail-fast).
 */
@ConfigurationProperties(prefix = "thumbsup.cors")
@Validated
public record CorsProperties(@NotEmpty List<String> allowedOriginPatterns) {}
