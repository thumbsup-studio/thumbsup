package studio.thumbsup.server.quiz;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.exception.GlobalExceptionHandler;
import studio.thumbsup.server.quiz.dto.HomeResponse;

/** Controller 슬라이스 테스트 — standalone MockMvc로 요청/응답 계약만 검증한다 (피라미드 2층). */
@ExtendWith(MockitoExtension.class)
class HomeControllerTest {

    @Mock
    private HomeService homeService;

    private MockMvc mockMvc;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(new HomeController(homeService))
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
    @DisplayName("홈 화면 조회")
    class GetHome {

        @Test
        @DisplayName("성공하면 200과 스트릭·포인트·오늘의 학습 데이터를 반환한다")
        void returns_200_with_home_data_on_success() throws Exception {
            authenticateAs(7L);
            HomeResponse response = new HomeResponse(
                    5, 320, true, new HomeResponse.TodayLearning(1L, "CS 기초", 2L, "스택과 큐", 2, 1, 3, 3));
            given(homeService.getHome(eq(7L))).willReturn(response);

            mockMvc.perform(get("/api/v1/home"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.streakDays").value(5))
                    .andExpect(jsonPath("$.data.points").value(320))
                    .andExpect(jsonPath("$.data.today.courseTitle").value("CS 기초"))
                    .andExpect(jsonPath("$.data.today.unitTitle").value("스택과 큐"))
                    .andExpect(jsonPath("$.data.today.totalCount").value(3))
                    .andExpect(jsonPath("$.data.todayCompleted").value(true));
        }

        @Test
        @DisplayName("기본 코스가 준비되지 않았으면 404 COURSE_NOT_FOUND를 반환한다")
        void returns_404_when_course_not_found() throws Exception {
            authenticateAs(7L);
            given(homeService.getHome(eq(7L))).willThrow(new BusinessException(LearningErrorType.COURSE_NOT_FOUND));

            mockMvc.perform(get("/api/v1/home"))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.code").value("COURSE_NOT_FOUND"));
        }
    }
}
