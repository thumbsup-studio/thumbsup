package studio.thumbsup.server.quiz.course;

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
import studio.thumbsup.server.common.exception.GlobalExceptionHandler;
import studio.thumbsup.server.quiz.course.dto.CourseListResponse;
import studio.thumbsup.server.quiz.course.dto.CourseListResponse.CourseItem;
import studio.thumbsup.server.quiz.course.dto.CourseListResponse.StepItem;
import studio.thumbsup.server.quiz.course.dto.CourseListResponse.StepState;

/** Controller 슬라이스 테스트 — standalone MockMvc로 요청/응답 계약만 검증한다 (피라미드 2층). */
@ExtendWith(MockitoExtension.class)
@DisplayName("코스 컨트롤러")
class CourseControllerTest {

    @Mock
    private CourseService courseService;

    private MockMvc mockMvc;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(new CourseController(courseService))
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
    @DisplayName("코스 목록 조회")
    class GetCourses {

        @Test
        @DisplayName("성공하면 200과 공통 envelope로 코스·스텝 목록을 반환한다")
        void returns_200_with_common_envelope() throws Exception {
            authenticateAs(7L);
            CourseItem item = new CourseItem(
                    1L,
                    "운영체제",
                    "CS",
                    List.of(
                            new StepItem(1, "스텝1", 5, StepState.COMPLETED),
                            new StepItem(2, "스텝2", 5, StepState.SOLVABLE)));
            given(courseService.getCourses(eq(7L))).willReturn(new CourseListResponse(List.of(item)));

            mockMvc.perform(get("/api/v1/courses"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.items[0].courseId").value(1))
                    .andExpect(jsonPath("$.data.items[0].title").value("운영체제"))
                    .andExpect(jsonPath("$.data.items[0].category").value("CS"))
                    .andExpect(jsonPath("$.data.items[0].steps[0].state").value("COMPLETED"))
                    .andExpect(jsonPath("$.data.items[0].steps[1].state").value("SOLVABLE"))
                    .andExpect(jsonPath("$.meta").doesNotExist());
        }

        @Test
        @DisplayName("코스가 없으면 빈 items 배열을 반환한다")
        void returns_empty_items_when_no_courses() throws Exception {
            authenticateAs(7L);
            given(courseService.getCourses(eq(7L))).willReturn(new CourseListResponse(List.of()));

            mockMvc.perform(get("/api/v1/courses"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.items").isEmpty());
        }
    }
}
