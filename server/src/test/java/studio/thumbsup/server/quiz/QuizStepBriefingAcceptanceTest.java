package studio.thumbsup.server.quiz;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.test.web.servlet.MockMvc;
import studio.thumbsup.server.common.security.JwtTokenProvider;
import studio.thumbsup.server.common.support.AcceptanceTestSupport;

/** 브리핑 조회부터 같은 스텝의 첫 문제 시작까지의 인증·DB·API 통합 흐름을 검증한다. */
class QuizStepBriefingAcceptanceTest extends AcceptanceTestSupport {

    private static final Long USER_ID = 701L;
    private static final Long OS_COURSE_ID = 1L;

    private final MockMvc mockMvc;
    private final JwtTokenProvider jwtTokenProvider;
    private final QuizStepRepository quizStepRepository;

    private Long firstStepId;

    QuizStepBriefingAcceptanceTest(
            @Autowired MockMvc mockMvc,
            @Autowired JwtTokenProvider jwtTokenProvider,
            @Autowired QuizStepRepository quizStepRepository) {
        this.mockMvc = mockMvc;
        this.jwtTokenProvider = jwtTokenProvider;
        this.quizStepRepository = quizStepRepository;
    }

    @BeforeEach
    void setUp() {
        QuizStep firstStep =
                quizStepRepository.findByCourseIdAndStepOrder(OS_COURSE_ID, 1).orElseThrow();
        firstStepId = firstStep.getId();
    }

    @Nested
    @DisplayName("브리핑을 읽고 문제를 시작한다")
    class StartQuizAfterBriefing {

        @Test
        @DisplayName("현재 코스 브리핑의 quizStepId로 같은 스텝 첫 문제를 조회한다")
        void returns_briefing_then_first_unattempted_quiz() throws Exception {
            mockMvc.perform(get("/api/v1/courses/{courseId}/next-step/briefing", OS_COURSE_ID)
                            .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.quizStepId").value(firstStepId))
                    .andExpect(jsonPath("$.data.blocks[0].heading").value("두 개의 실행 영역"));

            mockMvc.perform(get("/api/v1/quiz-steps/{quizStepId}/quizzes/next", firstStepId)
                            .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.stepOrder").value(1))
                    .andExpect(jsonPath("$.data.slotOrder").value(1));
        }
    }

    @Nested
    @DisplayName("인증")
    class Authentication {

        @Test
        @DisplayName("인증 없이 브리핑을 조회하면 401을 반환한다")
        void rejects_unauthenticated_briefing_request() throws Exception {
            mockMvc.perform(get("/api/v1/courses/{courseId}/next-step/briefing", OS_COURSE_ID))
                    .andExpect(status().isUnauthorized());
        }
    }

    private String bearerToken() {
        return "Bearer " + jwtTokenProvider.createAccessToken(USER_ID);
    }
}
