package studio.thumbsup.server.quiz.authoring;

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
import org.springframework.http.MediaType;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.method.annotation.AuthenticationPrincipalArgumentResolver;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import studio.thumbsup.server.common.exception.GlobalExceptionHandler;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringQuizListResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringQuizSummaryResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringStepResponse;
import studio.thumbsup.server.quiz.authoring.dto.ImproveRequest;

/** Controller 슬라이스 테스트 — standalone MockMvc로 요청/응답 계약만 검증한다 (피라미드 2층). */
@ExtendWith(MockitoExtension.class)
class AuthoringQuizControllerTest {

    @Mock
    private AuthoringJobService jobService;

    @Mock
    private AuthoringQuizService quizService;

    private MockMvc mockMvc;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(new AuthoringQuizController(jobService, quizService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .setMessageConverters(new MappingJackson2HttpMessageConverter(objectMapper))
                .setCustomArgumentResolvers(new AuthenticationPrincipalArgumentResolver())
                .build();
        SecurityContextHolder.getContext()
                .setAuthentication(new UsernamePasswordAuthenticationToken(7L, null, List.of()));
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Nested
    @DisplayName("개선 잡 등록")
    class Improve {

        @Test
        @DisplayName("성공하면 202와 draftId·jobId를 반환한다")
        void returns_202_with_draft_id_and_job_id_on_success() throws Exception {
            given(jobService.enqueueImprove(eq(7L), eq(5L), eq("선지를 더 명확하게")))
                    .willReturn(new AuthoringJobService.ImproveEnqueued(10L, 20L));

            mockMvc.perform(post("/api/v1/authoring/quizzes/5/improve")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(new ImproveRequest("선지를 더 명확하게"))))
                    .andExpect(status().isAccepted())
                    .andExpect(jsonPath("$.data.draftId").value(10))
                    .andExpect(jsonPath("$.data.jobId").value(20));
        }

        @Test
        @DisplayName("instruction이 공백이면 400 INVALID_INPUT을 반환한다")
        void returns_400_when_instruction_is_blank() throws Exception {
            mockMvc.perform(post("/api/v1/authoring/quizzes/5/improve")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(new ImproveRequest("   "))))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("INVALID_INPUT"));
        }
    }

    @Nested
    @DisplayName("목록 조회")
    class ListQuizzes {

        @Test
        @DisplayName("성공하면 200과 steps 배열을 반환한다")
        void returns_200_with_steps_array_on_success() throws Exception {
            AuthoringQuizSummaryResponse quiz = new AuthoringQuizSummaryResponse(1L, 1, "OX", "EASY", "질문");
            AuthoringStepResponse step = new AuthoringStepResponse(1, "운영체제", List.of(quiz));
            given(quizService.listQuizzes()).willReturn(new AuthoringQuizListResponse(List.of(step)));

            mockMvc.perform(get("/api/v1/authoring/quizzes"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.steps[0].stepOrder").value(1))
                    .andExpect(jsonPath("$.data.steps[0].quizzes[0].quizId").value(1));
        }
    }
}
