package studio.thumbsup.server.quiz.authoring;

import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.willThrow;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Collections;
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
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.exception.GlobalExceptionHandler;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizType;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseDetailResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseListResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringDetailedQuizResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringDetailedStepResponse;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;

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

    @Test
    @DisplayName("코스 상세는 200과 스텝·문제 전체 상세(generated)를 반환한다")
    void returns_200_with_detailed_quizzes() throws Exception {
        GeneratedQuizSet.GeneratedQuiz generated = new GeneratedQuizSet.GeneratedQuiz(
                QuizType.OX,
                QuizDifficulty.EASY,
                "커널은 특권 수준에서 실행된다.",
                null,
                "커널은 하드웨어 자원을 관리한다.",
                null,
                "사용자 모드와 혼동하면 안 된다.",
                "O",
                null,
                null,
                Collections.emptyList(),
                Collections.emptyList(),
                List.of(new GeneratedQuizSet.GeneratedKeyword("커널", "OS의 핵심")));
        AuthoringDetailedQuizResponse quiz = new AuthoringDetailedQuizResponse(101L, 1, generated);
        AuthoringDetailedStepResponse step = new AuthoringDetailedStepResponse(1, "OS 개요", List.of(quiz));
        given(courseService.getCourseQuizzes(1L))
                .willReturn(new AuthoringCourseDetailResponse(1L, "운영체제", List.of(step)));

        mockMvc.perform(get("/api/v1/authoring/courses/1/quizzes"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.title").value("운영체제"))
                .andExpect(jsonPath("$.data.steps[0].quizzes[0].quizId").value(101))
                .andExpect(jsonPath("$.data.steps[0].quizzes[0].generated.questionText")
                        .value("커널은 특권 수준에서 실행된다."))
                .andExpect(jsonPath("$.data.steps[0].quizzes[0].generated.correctAnswer")
                        .value("O"))
                .andExpect(jsonPath("$.data.steps[0].quizzes[0].generated.keywords[0].keyword")
                        .value("커널"));
    }

    @Test
    @DisplayName("없는 코스는 404 AUTHORING_COURSE_NOT_FOUND를 반환한다")
    void returns_404_when_course_not_found() throws Exception {
        willThrow(new BusinessException(AuthoringErrorType.AUTHORING_COURSE_NOT_FOUND))
                .given(courseService)
                .getCourseQuizzes(999L);

        mockMvc.perform(get("/api/v1/authoring/courses/999/quizzes"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("AUTHORING_COURSE_NOT_FOUND"));
    }
}
