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
import studio.thumbsup.server.quiz.dto.QuizNextResponse;

/** Controller 슬라이스 테스트 — standalone MockMvc로 요청/응답 계약만 검증한다 (피라미드 2층). */
@ExtendWith(MockitoExtension.class)
class QuizControllerTest {

    @Mock
    private QuizService quizService;

    private MockMvc mockMvc;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(new QuizController(quizService))
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
    @DisplayName("다음 문제 조회")
    class GetNextQuiz {

        @Test
        @DisplayName("성공하면 200과 문제 데이터를 반환한다")
        void returns_200_with_quiz_data_on_success() throws Exception {
            authenticateAs(7L);
            QuizNextResponse response = new QuizNextResponse(
                    1L, QuizType.OX, QuizDifficulty.EASY, "TCP는 연결 지향 프로토콜이다.", null, null, null, 1, 1);
            given(quizService.getNextQuiz(eq(7L))).willReturn(response);

            mockMvc.perform(get("/api/v1/quizzes/next"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.quizId").value(1))
                    .andExpect(jsonPath("$.data.type").value("OX"));
        }

        @Test
        @DisplayName("스텝을 모두 풀었으면 404 QUIZ_STEP_COMPLETED를 반환한다")
        void returns_404_when_step_completed() throws Exception {
            authenticateAs(7L);
            given(quizService.getNextQuiz(eq(7L))).willThrow(new BusinessException(QuizErrorType.QUIZ_STEP_COMPLETED));

            mockMvc.perform(get("/api/v1/quizzes/next"))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.code").value("QUIZ_STEP_COMPLETED"));
        }
    }
}
