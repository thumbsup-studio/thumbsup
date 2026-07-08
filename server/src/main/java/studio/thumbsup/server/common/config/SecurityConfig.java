package studio.thumbsup.server.common.config;

import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import studio.thumbsup.server.common.logging.RequestIdFilter;
import studio.thumbsup.server.common.security.JwtAccessDeniedHandler;
import studio.thumbsup.server.common.security.JwtAuthenticationEntryPoint;
import studio.thumbsup.server.common.security.JwtAuthenticationFilter;
import studio.thumbsup.server.common.security.JwtTokenProvider;

/**
 * JWT stateless 보안 설정 — 기본 거부(deny-by-default), 명시된 경로만 공개.
 * 인증 계약: docs/api-standard.md §8, 401/403 응답 형식: docs/error-spec.md.
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private static final String SWAGGER_ROLE = "SWAGGER";
    private static final String[] SWAGGER_PATHS = {
        "/swagger-ui.html", "/swagger-ui/**", "/v3/api-docs", "/v3/api-docs/**", "/v3/api-docs.yaml",
    };
    private static final String[] PUBLIC_PATHS = {
        "/actuator/health", "/api/v1/auth/signup", "/api/v1/auth/login", "/api/v1/auth/refresh",
    };

    private final JwtTokenProvider jwtTokenProvider;
    private final JwtAuthenticationEntryPoint authenticationEntryPoint;
    private final JwtAccessDeniedHandler accessDeniedHandler;

    public SecurityConfig(
            JwtTokenProvider jwtTokenProvider,
            JwtAuthenticationEntryPoint authenticationEntryPoint,
            JwtAccessDeniedHandler accessDeniedHandler) {
        this.jwtTokenProvider = jwtTokenProvider;
        this.authenticationEntryPoint = authenticationEntryPoint;
        this.accessDeniedHandler = accessDeniedHandler;
    }

    @Bean
    @Order(1)
    public SecurityFilterChain swaggerFilterChain(
            HttpSecurity http, AuthenticationProvider swaggerAuthenticationProvider) throws Exception {
        http.securityMatcher(SWAGGER_PATHS)
                .csrf(AbstractHttpConfigurer::disable)
                .cors(Customizer.withDefaults())
                .formLogin(AbstractHttpConfigurer::disable)
                .httpBasic(basic -> basic.realmName("Thumbs Up Swagger"))
                .logout(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authenticationProvider(swaggerAuthenticationProvider)
                .authorizeHttpRequests(auth -> auth.anyRequest().hasRole(SWAGGER_ROLE));
        return http.build();
    }

    @Bean
    @Order(2)
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.csrf(AbstractHttpConfigurer::disable)
                .cors(Customizer.withDefaults())
                .formLogin(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .logout(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth.requestMatchers(PUBLIC_PATHS)
                        .permitAll()
                        .anyRequest()
                        .authenticated())
                .exceptionHandling(handling -> handling.authenticationEntryPoint(authenticationEntryPoint)
                        .accessDeniedHandler(accessDeniedHandler))
                .addFilterBefore(
                        new JwtAuthenticationFilter(jwtTokenProvider), UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    public AuthenticationProvider swaggerAuthenticationProvider(
            SwaggerBasicAuthProperties properties, PasswordEncoder passwordEncoder) {
        String encodedPassword = passwordEncoder.encode(properties.password());
        return new AuthenticationProvider() {
            @Override
            public Authentication authenticate(Authentication authentication) {
                String username = authentication.getName();
                String password = authentication.getCredentials() == null
                        ? ""
                        : authentication.getCredentials().toString();
                boolean usernameMatches = properties.username().equals(username);
                boolean passwordMatches = passwordEncoder.matches(password, encodedPassword);
                if (!usernameMatches || !passwordMatches) {
                    throw new BadCredentialsException("Invalid Swagger credentials");
                }
                return UsernamePasswordAuthenticationToken.authenticated(
                        username, null, AuthorityUtils.createAuthorityList("ROLE_" + SWAGGER_ROLE));
            }

            @Override
            public boolean supports(Class<?> authentication) {
                return UsernamePasswordAuthenticationToken.class.isAssignableFrom(authentication);
            }
        };
    }

    /** 자체 로그인(auth feature)의 비밀번호 해시용 */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /** CORS 계약: docs/api-standard.md §9 — 허용 origin pattern은 프로파일별 thumbsup.cors.allowed-origin-patterns */
    @Bean
    public CorsConfigurationSource corsConfigurationSource(CorsProperties corsProperties) {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(corsProperties.allowedOriginPatterns());
        config.setAllowCredentials(true);
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(
                List.of(HttpHeaders.AUTHORIZATION, HttpHeaders.CONTENT_TYPE, RequestIdFilter.HEADER_NAME));
        config.setExposedHeaders(List.of(RequestIdFilter.HEADER_NAME));
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
