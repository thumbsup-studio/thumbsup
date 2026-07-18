package studio.thumbsup.server.quiz.authoring;

import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import studio.thumbsup.server.common.exception.GlobalExceptionHandler;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseListResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseResponse;

/** Controller 슬라이스 테스트 — standalone MockMvc로 요청/응답 계약만 검증한다. */
@ExtendWith(MockitoExtension.class)
class AuthoringCourseControllerTest {

    @Mock
    private AuthoringCourseService courseService;

    private MockMvc mockMvc;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(new AuthoringCourseController(courseService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .setMessageConverters(new MappingJackson2HttpMessageConverter(objectMapper))
                .build();
    }

    @Test
    @DisplayName("코스 목록은 200과 courses 배열을 반환한다")
    void returns_200_with_courses() throws Exception {
        given(courseService.listCourses())
                .willReturn(new AuthoringCourseListResponse(List.of(new AuthoringCourseResponse(1L, "운영체제", "CS"))));

        mockMvc.perform(get("/api/v1/authoring/courses"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.courses[0].courseId").value(1))
                .andExpect(jsonPath("$.data.courses[0].title").value("운영체제"));
    }
}
