package studio.thumbsup.server.quiz;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
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
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.exception.GlobalExceptionHandler;
import studio.thumbsup.server.quiz.dto.AnswerSubmitRequest;
import studio.thumbsup.server.quiz.dto.AnswerSubmitResponse;
import studio.thumbsup.server.quiz.dto.QuizExplanationResponse;
import studio.thumbsup.server.quiz.dto.QuizHintResponse;
import studio.thumbsup.server.quiz.dto.QuizNextResponse;
import studio.thumbsup.server.quiz.dto.QuizStepHistoryResponse;

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
                    1L, QuizType.OX, QuizDifficulty.EASY, "TCP는 연결 지향 프로토콜이다.", null, null, null, 1, 1, 5);
            given(quizService.getNextQuiz(eq(7L), isNull())).willReturn(response);

            mockMvc.perform(get("/api/v1/quizzes/next"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.quizId").value(1))
                    .andExpect(jsonPath("$.data.type").value("OX"))
                    .andExpect(jsonPath("$.data.totalCount").value(5));
        }

        @Test
        @DisplayName("스텝을 모두 풀었으면 404 QUIZ_STEP_COMPLETED를 반환한다")
        void returns_404_when_step_completed() throws Exception {
            authenticateAs(7L);
            given(quizService.getNextQuiz(eq(7L), isNull()))
                    .willThrow(new BusinessException(QuizErrorType.QUIZ_STEP_COMPLETED));

            mockMvc.perform(get("/api/v1/quizzes/next"))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.code").value("QUIZ_STEP_COMPLETED"));
        }
    }

    @Nested
    @DisplayName("완료한 스텝 이력 조회")
    class GetCompletedSteps {

        @Test
        @DisplayName("성공하면 200과 완료한 스텝 목록을 반환한다")
        void returns_200_with_completed_steps() throws Exception {
            authenticateAs(7L);
            given(quizService.getCompletedSteps(eq(7L), isNull()))
                    .willReturn(new QuizStepHistoryResponse(List.of(
                            new QuizStepHistoryResponse.Item(1, "프로세스와 스레드"),
                            new QuizStepHistoryResponse.Item(2, "CPU 스케줄링"))));

            mockMvc.perform(get("/api/v1/quizzes/steps/completed"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.steps.length()").value(2))
                    .andExpect(jsonPath("$.data.steps[0].stepOrder").value(1))
                    .andExpect(jsonPath("$.data.steps[0].topic").value("프로세스와 스레드"));
        }

        @Test
        @DisplayName("완료한 스텝이 없으면 빈 배열을 반환한다")
        void returns_empty_array_when_no_completed_steps() throws Exception {
            authenticateAs(7L);
            given(quizService.getCompletedSteps(eq(7L), isNull())).willReturn(new QuizStepHistoryResponse(List.of()));

            mockMvc.perform(get("/api/v1/quizzes/steps/completed"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.steps.length()").value(0));
        }
    }

    @Nested
    @DisplayName("스텝 내 문제 재조회")
    class GetStepQuiz {

        @Test
        @DisplayName("성공하면 200과 지정한 슬롯의 문제를 반환한다")
        void returns_200_with_slot_quiz() throws Exception {
            authenticateAs(7L);
            QuizNextResponse response = new QuizNextResponse(
                    30L, QuizType.OX, QuizDifficulty.EASY, "TCP는 연결 지향 프로토콜이다.", null, null, null, 1, 3, 4);
            given(quizService.getStepQuiz(eq(7L), eq(1), eq(3))).willReturn(response);

            mockMvc.perform(get("/api/v1/quizzes/steps/1/3"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.quizId").value(30))
                    .andExpect(jsonPath("$.data.slotOrder").value(3));
        }

        @Test
        @DisplayName("미래 스텝이면 403 QUIZ_NOT_ACCESSIBLE을 반환한다")
        void returns_403_when_step_not_accessible() throws Exception {
            authenticateAs(7L);
            given(quizService.getStepQuiz(eq(7L), eq(5), eq(1)))
                    .willThrow(new BusinessException(QuizErrorType.QUIZ_NOT_ACCESSIBLE));

            mockMvc.perform(get("/api/v1/quizzes/steps/5/1"))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.code").value("QUIZ_NOT_ACCESSIBLE"));
        }

        @Test
        @DisplayName("존재하지 않는 스텝·슬롯이면 404 QUIZ_NOT_FOUND를 반환한다")
        void returns_404_when_slot_not_found() throws Exception {
            authenticateAs(7L);
            given(quizService.getStepQuiz(eq(7L), eq(1), eq(9)))
                    .willThrow(new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));

            mockMvc.perform(get("/api/v1/quizzes/steps/1/9"))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.code").value("QUIZ_NOT_FOUND"));
        }
    }

    @Nested
    @DisplayName("정답 제출")
    class SubmitAnswer {

        @Test
        @DisplayName("성공하면 200과 채점 결과를 반환한다")
        void returns_200_with_grading_result() throws Exception {
            authenticateAs(7L);
            given(quizService.submitAnswer(eq(7L), eq(1L), eq(new AnswerSubmitRequest(List.of("O")))))
                    .willReturn(new AnswerSubmitResponse(true, null));

            mockMvc.perform(post("/api/v1/quizzes/1/answers")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(new AnswerSubmitRequest(List.of("O")))))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.isCorrect").value(true));
        }

        @Test
        @DisplayName("답을 비워 제출하면 400 INVALID_INPUT")
        void returns_400_when_answers_empty() throws Exception {
            authenticateAs(7L);

            mockMvc.perform(post("/api/v1/quizzes/1/answers")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(new AnswerSubmitRequest(List.of()))))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("INVALID_INPUT"));
        }

        @Test
        @DisplayName("존재하지 않는 퀴즈면 404 QUIZ_NOT_FOUND")
        void returns_404_when_quiz_not_found() throws Exception {
            authenticateAs(7L);
            given(quizService.submitAnswer(eq(7L), eq(999L), eq(new AnswerSubmitRequest(List.of("O")))))
                    .willThrow(new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));

            mockMvc.perform(post("/api/v1/quizzes/999/answers")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(new AnswerSubmitRequest(List.of("O")))))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.code").value("QUIZ_NOT_FOUND"));
        }

        @Test
        @DisplayName("아직 진행하지 않은 미래 스텝의 문제면 403 QUIZ_NOT_ACCESSIBLE")
        void returns_403_when_quiz_not_accessible() throws Exception {
            authenticateAs(7L);
            given(quizService.submitAnswer(eq(7L), eq(1L), eq(new AnswerSubmitRequest(List.of("O")))))
                    .willThrow(new BusinessException(QuizErrorType.QUIZ_NOT_ACCESSIBLE));

            mockMvc.perform(post("/api/v1/quizzes/1/answers")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(new AnswerSubmitRequest(List.of("O")))))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.code").value("QUIZ_NOT_ACCESSIBLE"));
        }
    }

    @Nested
    @DisplayName("풀이 중 힌트 요청")
    class GetHint {

        @Test
        @DisplayName("성공하면 200과 단일 hint 문자열을 반환한다")
        void returns_200_with_hint() throws Exception {
            authenticateAs(7L);
            given(quizService.getHint(7L, 1L)).willReturn(new QuizHintResponse("핵심 조건을 서로 비교해 보세요."));

            mockMvc.perform(post("/api/v1/quizzes/1/hints"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.hint").value("핵심 조건을 서로 비교해 보세요."))
                    .andExpect(jsonPath("$.data.eliminatedChoiceId").doesNotExist())
                    .andExpect(jsonPath("$.data.blankHints").doesNotExist());
        }

        @Test
        @DisplayName("미래 스텝 문제면 403 QUIZ_NOT_ACCESSIBLE을 반환한다")
        void returns_403_when_quiz_not_accessible() throws Exception {
            authenticateAs(7L);
            given(quizService.getHint(7L, 1L)).willThrow(new BusinessException(QuizErrorType.QUIZ_NOT_ACCESSIBLE));

            mockMvc.perform(post("/api/v1/quizzes/1/hints"))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.code").value("QUIZ_NOT_ACCESSIBLE"));
        }

        @Test
        @DisplayName("점진 백필에서 힌트가 없는 문제면 409 QUIZ_HINT_NOT_AVAILABLE을 반환한다")
        void returns_409_when_hint_is_not_available() throws Exception {
            authenticateAs(7L);
            given(quizService.getHint(7L, 1L)).willThrow(new BusinessException(QuizErrorType.QUIZ_HINT_NOT_AVAILABLE));

            mockMvc.perform(post("/api/v1/quizzes/1/hints"))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.code").value("QUIZ_HINT_NOT_AVAILABLE"));
        }
    }

    @Nested
    @DisplayName("해설 조회")
    class GetExplanation {

        private QuizExplanationResponse explanationResponse() {
            return new QuizExplanationResponse(
                    1L,
                    "TCP는 연결 지향 프로토콜이다.",
                    QuizType.OX,
                    QuizDifficulty.EASY,
                    1,
                    5,
                    "CS 기초",
                    "네트워크 기초",
                    List.of(new QuizExplanationResponse.AnnotatedText(
                            "TCP는 연결 지향 프로토콜이다.", List.of(new QuizExplanationResponse.Highlight("연결 지향", 5, 10)))),
                    null,
                    new QuizExplanationResponse.AnnotatedText("UDP는 비연결형이다.", List.of()),
                    List.of(new QuizExplanationResponse.KeywordItem("연결 지향", "통신 전에 연결을 먼저 수립하는 방식")),
                    List.of(new QuizExplanationResponse.FollowUpQuestionItem(10L, "대표 질문입니다.", true)));
        }

        @Test
        @DisplayName("성공하면 200과 해설 데이터를 반환한다")
        void returns_200_with_explanation_data() throws Exception {
            given(quizService.getExplanation(eq(1L))).willReturn(explanationResponse());

            mockMvc.perform(get("/api/v1/quizzes/1/explanation"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.quizId").value(1))
                    .andExpect(jsonPath("$.data.questionText").value("TCP는 연결 지향 프로토콜이다."))
                    .andExpect(jsonPath("$.data.type").value("OX"))
                    .andExpect(jsonPath("$.data.difficulty").value("EASY"))
                    .andExpect(jsonPath("$.data.currentNumber").value(1))
                    .andExpect(jsonPath("$.data.totalCount").value(5))
                    .andExpect(jsonPath("$.data.courseTitle").value("CS 기초"))
                    .andExpect(jsonPath("$.data.unitTitle").value("네트워크 기초"))
                    .andExpect(jsonPath("$.data.explanationSummary[0].text").value("TCP는 연결 지향 프로토콜이다."))
                    .andExpect(jsonPath("$.data.explanationSummary[0].highlights[0].keyword")
                            .value("연결 지향"))
                    .andExpect(jsonPath("$.data.explanationSummary[0].highlights[0].start")
                            .value(5))
                    .andExpect(jsonPath("$.data.explanationExample").isEmpty())
                    .andExpect(jsonPath("$.data.wrongAnswerExplanation.text").value("UDP는 비연결형이다."))
                    .andExpect(jsonPath("$.data.followUpQuestions[0].followUpQuestionId")
                            .value(10))
                    .andExpect(jsonPath("$.data.followUpQuestions[0].content").value("대표 질문입니다."))
                    .andExpect(jsonPath("$.data.followUpQuestions[0].isPrimary").value(true));
        }

        @Test
        @DisplayName("존재하지 않는 문제면 404 QUIZ_NOT_FOUND를 반환한다")
        void returns_404_when_quiz_is_absent() throws Exception {
            given(quizService.getExplanation(eq(999L))).willThrow(new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));

            mockMvc.perform(get("/api/v1/quizzes/999/explanation"))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.code").value("QUIZ_NOT_FOUND"));
        }

        @Test
        @DisplayName("기본 코스가 없으면 404 COURSE_NOT_FOUND를 반환한다")
        void returns_404_when_course_is_absent() throws Exception {
            given(quizService.getExplanation(eq(1L)))
                    .willThrow(new BusinessException(LearningErrorType.COURSE_NOT_FOUND));

            mockMvc.perform(get("/api/v1/quizzes/1/explanation"))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.code").value("COURSE_NOT_FOUND"));
        }
    }
}
