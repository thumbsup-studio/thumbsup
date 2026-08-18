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
import studio.thumbsup.server.quiz.dto.QuizStepBriefingResponse;

/** 브리핑 API의 경로·인증 주체·성공과 오류 envelope 계약을 검증한다. */
@ExtendWith(MockitoExtension.class)
class QuizStepBriefingControllerTest {

    @Mock
    private QuizStepBriefingService briefingService;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(new QuizStepBriefingController(briefingService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .setMessageConverters(new MappingJackson2HttpMessageConverter(new ObjectMapper()))
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
    @DisplayName("현재 스텝 브리핑 조회")
    class GetNextBriefing {

        @Test
        @DisplayName("성공하면 200과 브리핑 데이터를 반환한다")
        void returns_briefing_response() throws Exception {
            QuizStepBriefingResponse response = new QuizStepBriefingResponse(
                    42L,
                    1L,
                    4,
                    "CPU 스케줄링",
                    "CPU가 다음 실행 대상을 고르는 원리를 살펴봅니다.",
                    List.of(new QuizStepBriefingResponse.Block(
                            QuizStepBriefingBlockType.CONCEPT, "핵심", "준비 큐를 기준으로 고릅니다.", 1)));
            given(briefingService.getNextBriefing(eq(7L), eq(1L))).willReturn(response);

            mockMvc.perform(get("/api/v1/courses/1/next-step/briefing"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.quizStepId").value(42))
                    .andExpect(jsonPath("$.data.blocks[0].type").value("CONCEPT"));
        }

        @Test
        @DisplayName("브리핑이 없으면 409 오류 코드를 반환한다")
        void returns_conflict_when_briefing_is_not_available() throws Exception {
            given(briefingService.getNextBriefing(eq(7L), eq(1L)))
                    .willThrow(new BusinessException(QuizErrorType.QUIZ_STEP_BRIEFING_NOT_AVAILABLE));

            mockMvc.perform(get("/api/v1/courses/1/next-step/briefing"))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.code").value("QUIZ_STEP_BRIEFING_NOT_AVAILABLE"));
        }
    }

    @Nested
    @DisplayName("브리핑 스텝의 다음 문제 조회")
    class GetNextQuizForStep {

        @Test
        @DisplayName("성공하면 200과 다음 문제를 반환한다")
        void returns_next_quiz_response() throws Exception {
            QuizNextResponse response =
                    new QuizNextResponse(8L, QuizType.OX, QuizDifficulty.EASY, "문제", null, null, null, 1L, 4, 1, 5);
            given(briefingService.getNextQuizForStep(eq(7L), eq(42L))).willReturn(response);

            mockMvc.perform(get("/api/v1/quiz-steps/42/quizzes/next"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.quizId").value(8))
                    .andExpect(jsonPath("$.data.slotOrder").value(1));
        }

        @Test
        @DisplayName("미래 스텝이면 403 QUIZ_NOT_ACCESSIBLE을 반환한다")
        void returns_forbidden_for_future_step() throws Exception {
            given(briefingService.getNextQuizForStep(eq(7L), eq(42L)))
                    .willThrow(new BusinessException(QuizErrorType.QUIZ_NOT_ACCESSIBLE));

            mockMvc.perform(get("/api/v1/quiz-steps/42/quizzes/next"))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.code").value("QUIZ_NOT_ACCESSIBLE"));
        }

        @Test
        @DisplayName("완료한 스텝이면 409 QUIZ_STEP_NOT_CURRENT를 반환한다")
        void returns_conflict_for_completed_step() throws Exception {
            given(briefingService.getNextQuizForStep(eq(7L), eq(42L)))
                    .willThrow(new BusinessException(QuizErrorType.QUIZ_STEP_NOT_CURRENT));

            mockMvc.perform(get("/api/v1/quiz-steps/42/quizzes/next"))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.code").value("QUIZ_STEP_NOT_CURRENT"));
        }
    }
}
