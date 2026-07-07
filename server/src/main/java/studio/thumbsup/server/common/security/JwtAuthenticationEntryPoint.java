package studio.thumbsup.server.common.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;
import studio.thumbsup.server.common.exception.CommonErrorType;
import studio.thumbsup.server.common.exception.ErrorType;
import studio.thumbsup.server.common.response.ApiResponse;

/**
 * 미인증(401) 응답도 공통 envelope로 — 시큐리티 필터 예외는 @RestControllerAdvice에 닿지 않으므로 여기서 변환한다.
 * 만료 토큰(TOKEN_EXPIRED)과 그 외(UNAUTHORIZED)를 구분해 FE의 재발급 분기를 지원한다.
 */
@Component
public class JwtAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final ObjectMapper objectMapper;

    public JwtAuthenticationEntryPoint(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response, AuthenticationException e)
            throws IOException {
        ErrorType errorType = Boolean.TRUE.equals(request.getAttribute(JwtAuthenticationFilter.EXPIRED_ATTRIBUTE))
                ? CommonErrorType.TOKEN_EXPIRED
                : CommonErrorType.UNAUTHORIZED;
        response.setStatus(errorType.getStatus().value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        objectMapper.writeValue(response.getWriter(), ApiResponse.error(errorType));
    }
}
