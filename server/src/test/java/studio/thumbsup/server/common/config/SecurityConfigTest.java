package studio.thumbsup.server.common.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import studio.thumbsup.server.common.logging.RequestIdFilter;

class SecurityConfigTest {

    @Test
    void CORS는_Vercel_preview_origin_pattern과_credentials를_허용한다() {
        CorsProperties corsProperties = new CorsProperties(
                List.of("http://localhost:3000", "https://thumbsup-app.vercel.app", "https://*-thumbsup.vercel.app"));
        SecurityConfig securityConfig = new SecurityConfig(null, null, null);

        CorsConfigurationSource source = securityConfig.corsConfigurationSource(corsProperties);
        CorsConfiguration config =
                source.getCorsConfiguration(new MockHttpServletRequest("OPTIONS", "/api/v1/notices"));

        assertThat(config).isNotNull();
        assertThat(config.getAllowedOriginPatterns()).containsExactlyElementsOf(corsProperties.allowedOriginPatterns());
        assertThat(config.getAllowCredentials()).isTrue();
        assertThat(config.checkOrigin("http://localhost:3000")).isEqualTo("http://localhost:3000");
        assertThat(config.checkOrigin("https://thumbsup-app.vercel.app")).isEqualTo("https://thumbsup-app.vercel.app");
        assertThat(config.checkOrigin("https://thumbsup-g0lba76ax-thumbsup.vercel.app"))
                .isEqualTo("https://thumbsup-g0lba76ax-thumbsup.vercel.app");
        assertThat(config.checkOrigin("https://other-team.vercel.app")).isNull();
        assertThat(config.getAllowedHeaders()).contains(RequestIdFilter.HEADER_NAME);
        assertThat(config.getExposedHeaders()).contains(RequestIdFilter.HEADER_NAME);
    }
}
