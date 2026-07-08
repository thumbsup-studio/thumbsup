package studio.thumbsup.server.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.security.JwtTokenProvider;

/**
 * SecurityConfig의 필터체인이 실제로 logout을 인증 필요 경로로 막는지 확인하는 인수 테스트.
 *
 * <p>{@code AuthControllerTest}는 standalone MockMvc로 {@code SecurityContextHolder}를 직접 채워서
 * 컨트롤러 계약만 검증하며 실제 필터체인을 통과하지 않는다 — SecurityConfig 규칙 변경 자체는 검증하지 못한다.
 * docs/testing-guide.md §3(필터체인에서 막히는 동작)·§6(인증 필요 API의 미인증 케이스) 기준에 따라
 * {@code @SpringBootTest}로 실제 필터체인을 부팅해 검증한다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@ActiveProfiles("test")
class AuthSecurityTest {

    private static final long TEST_USER_ID = 999L;

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final MockMvc mockMvc;
    private final JwtTokenProvider jwtTokenProvider;

    AuthSecurityTest(@Autowired MockMvc mockMvc, @Autowired JwtTokenProvider jwtTokenProvider) {
        this.mockMvc = mockMvc;
        this.jwtTokenProvider = jwtTokenProvider;
    }

    @Nested
    @DisplayName("POST /api/v1/auth/logout")
    class Logout {

        @Test
        @DisplayName("Authorization 헤더가 없으면 필터체인이 401로 막는다")
        void without_token_returns_401() throws Exception {
            mockMvc.perform(post("/api/v1/auth/logout")).andExpect(status().isUnauthorized());
        }

        @Test
        @DisplayName("유효한 access token이 있으면 필터체인을 통과해 200을 반환한다")
        void with_valid_token_returns_200() throws Exception {
            String accessToken = jwtTokenProvider.createAccessToken(TEST_USER_ID);

            mockMvc.perform(post("/api/v1/auth/logout").header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"));
        }
    }

    @Nested
    @DisplayName("POST /api/v1/auth/login")
    class Login {

        @Test
        @DisplayName("공개 경로이므로 인증 없이도 필터체인을 통과한다 (요청 검증 실패는 400이지 필터체인 401이 아니다)")
        void is_not_blocked_by_filter_chain() throws Exception {
            mockMvc.perform(post("/api/v1/auth/login")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{}"))
                    .andExpect(result ->
                            assertThat(result.getResponse().getStatus()).isNotEqualTo(401));
        }
    }
}
