package studio.thumbsup.server.common.config;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * CORS 허용 origin — 프로파일별 주입 (local=application-local.yml, prod=SSM ${CORS_ALLOWED_ORIGINS}).
 * default 없음 (fail-fast).
 */
@ConfigurationProperties(prefix = "thumbsup.cors")
public record CorsProperties(List<String> allowedOrigins) {}
