package studio.thumbsup.server.feedback;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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
 * SecurityConfig의 필터체인이 실제로 이 API를 인증 필요 경로로 막는지 확인하는 인수 테스트.
 * 패턴 출처: {@code auth.AuthSecurityTest} — standalone MockMvc는 필터체인을 통과하지 않으므로
 * SecurityConfig 규칙 변경 자체는 이 테스트로만 검증된다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@ActiveProfiles("test")
class FeedbackSecurityTest {

    private static final long TEST_USER_ID = 999L;

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final MockMvc mockMvc;
    private final JwtTokenProvider jwtTokenProvider;

    FeedbackSecurityTest(@Autowired MockMvc mockMvc, @Autowired JwtTokenProvider jwtTokenProvider) {
        this.mockMvc = mockMvc;
        this.jwtTokenProvider = jwtTokenProvider;
    }

    @Nested
    @DisplayName("POST /api/v1/feedbacks")
    class CreateFeedback {

        @Test
        @DisplayName("Authorization 헤더가 없으면 필터체인이 401로 막는다")
        void without_token_returns_401() throws Exception {
            mockMvc.perform(post("/api/v1/feedbacks")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"content\":\"좋아요\"}"))
                    .andExpect(status().isUnauthorized());
        }

        @Test
        @DisplayName("유효한 access token이 있으면 필터체인을 통과해 201을 반환한다")
        void with_valid_token_returns_201() throws Exception {
            String accessToken = jwtTokenProvider.createAccessToken(TEST_USER_ID);

            mockMvc.perform(post("/api/v1/feedbacks")
                            .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"content\":\"좋아요\"}"))
                    .andExpect(status().isCreated());
        }
    }
}
