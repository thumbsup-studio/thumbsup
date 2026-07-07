package studio.thumbsup.server.common.security;

import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import org.springframework.http.HttpHeaders;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Bearer 토큰을 검증해 SecurityContext에 userId를 싣는다.
 *
 * <p>유저 식별은 오직 이 토큰에서만 한다 — request body/param의 userId는 신뢰하지 않는다(IDOR 방지).
 * 실패 시 여기서 응답하지 않고 미인증으로 통과시킨다 — 401 변환은 {@link JwtAuthenticationEntryPoint} 몫.
 *
 * <p>SecurityConfig에서 직접 생성해 등록한다 (@Component로 만들면 서블릿 필터로 중복 등록됨).
 */
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    /** 만료 토큰 표시 — EntryPoint가 UNAUTHORIZED 대신 TOKEN_EXPIRED를 내려주기 위한 request attribute */
    public static final String EXPIRED_ATTRIBUTE = "thumbsup.jwt.expired";

    private static final String BEARER_PREFIX = "Bearer ";

    private final JwtTokenProvider tokenProvider;

    public JwtAuthenticationFilter(JwtTokenProvider tokenProvider) {
        this.tokenProvider = tokenProvider;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String token = resolveToken(request);
        if (token != null) {
            authenticate(request, token);
        }
        filterChain.doFilter(request, response);
    }

    private void authenticate(HttpServletRequest request, String token) {
        try {
            Long userId = tokenProvider.parseUserId(token);
            var authentication = new UsernamePasswordAuthenticationToken(userId, null, List.of());
            SecurityContextHolder.getContext().setAuthentication(authentication);
        } catch (ExpiredJwtException e) {
            request.setAttribute(EXPIRED_ATTRIBUTE, Boolean.TRUE);
        } catch (JwtException | IllegalArgumentException e) {
            // 무효 토큰 — 미인증으로 진행하면 EntryPoint가 UNAUTHORIZED로 응답한다
        }
    }

    private String resolveToken(HttpServletRequest request) {
        String bearer = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (bearer != null && bearer.startsWith(BEARER_PREFIX)) {
            return bearer.substring(BEARER_PREFIX.length());
        }
        return null;
    }
}
