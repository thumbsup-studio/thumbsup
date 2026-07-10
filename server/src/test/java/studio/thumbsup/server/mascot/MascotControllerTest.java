package studio.thumbsup.server.mascot;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.method.annotation.AuthenticationPrincipalArgumentResolver;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import studio.thumbsup.server.common.exception.GlobalExceptionHandler;
import studio.thumbsup.server.mascot.dto.MascotResponse;

/** Controller 슬라이스 테스트 — standalone MockMvc로 요청/응답 계약만 검증한다 (피라미드 2층). */
@ExtendWith(MockitoExtension.class)
class MascotControllerTest {

    @Mock
    private MascotService mascotService;

    private MockMvc mockMvc;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(new MascotController(mascotService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .setMessageConverters(new MappingJackson2HttpMessageConverter(objectMapper))
                .setCustomArgumentResolvers(new AuthenticationPrincipalArgumentResolver())
                .build();
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    private void authenticateAs(Long userId) {
        SecurityContextHolder.getContext()
                .setAuthentication(new UsernamePasswordAuthenticationToken(userId, null, List.of()));
    }

    @Nested
    @DisplayName("보리 상태 조회")
    class GetMascot {

        @Test
        @DisplayName("성공하면 200과 이름·포만감을 반환한다")
        void returns_200_with_mascot_data() throws Exception {
            authenticateAs(7L);
            given(mascotService.getMascot(eq(7L))).willReturn(new MascotResponse("보리", 62));

            mockMvc.perform(get("/api/v1/mascot"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.name").value("보리"))
                    .andExpect(jsonPath("$.data.fullness").value(62));
        }
    }

    @Nested
    @DisplayName("먹이 주기")
    class Feed {

        @Test
        @DisplayName("성공하면 200과 갱신된 포만감을 반환한다")
        void returns_200_with_updated_fullness() throws Exception {
            authenticateAs(7L);
            given(mascotService.feed(eq(7L))).willReturn(new MascotResponse("보리", 80));

            mockMvc.perform(post("/api/v1/mascot/feed"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.fullness").value(80));
        }
    }
}
