package studio.thumbsup.server.quiz;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.exception.GlobalExceptionHandler;
import studio.thumbsup.server.quiz.dto.FollowUpQuestionDetailResponse;

/** Controller 슬라이스 테스트 — standalone MockMvc로 요청/응답 계약만 검증한다 (피라미드 2층). */
@ExtendWith(MockitoExtension.class)
class FollowUpQuestionControllerTest {

    private static final long FOLLOW_UP_QUESTION_ID = 17L;
    private static final long ABSENT_ID = 999L;

    @Mock
    private QuizFollowUpQuestionService quizFollowUpQuestionService;

    private MockMvc mockMvc;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(new FollowUpQuestionController(quizFollowUpQuestionService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .setMessageConverters(new MappingJackson2HttpMessageConverter(objectMapper))
                .build();
    }

    private static FollowUpQuestionDetailResponse detailResponse() {
        FollowUpQuestionDetailResponse.AnnotatedText oneLineAnswer = new FollowUpQuestionDetailResponse.AnnotatedText(
                "정렬이 안 됐다면 선형 탐색이 기본입니다.", List.of(new FollowUpQuestionDetailResponse.Highlight("선형 탐색", 10, 15)));

        return new FollowUpQuestionDetailResponse(
                FOLLOW_UP_QUESTION_ID,
                3L,
                3,
                QuizDifficulty.MEDIUM,
                "정렬되어 있지 않은 배열이라면 어떻게 찾아야 할까?",
                oneLineAnswer,
                List.of(new FollowUpQuestionDetailResponse.DetailBlock(
                        "해설",
                        FollowUpBlockType.TEXT,
                        new FollowUpQuestionDetailResponse.AnnotatedText("선형 탐색은 O(n)이다.", List.of()))),
                List.of(new FollowUpQuestionDetailResponse.KeywordItem("선형 탐색", "앞에서부터 하나씩 확인하는 탐색 방법")));
    }

    @Nested
    @DisplayName("꼬리질문 상세 조회")
    class GetFollowUpQuestion {

        @Test
        @DisplayName("성공하면 200과 꼬리질문 상세를 envelope에 담아 반환한다")
        void returns_200_with_detail() throws Exception {
            given(quizFollowUpQuestionService.getDetail(eq(FOLLOW_UP_QUESTION_ID)))
                    .willReturn(detailResponse());

            mockMvc.perform(get("/api/v1/follow-up-questions/{followUpQuestionId}", FOLLOW_UP_QUESTION_ID))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.followUpQuestionId").value(FOLLOW_UP_QUESTION_ID))
                    .andExpect(jsonPath("$.data.sourceQuizId").value(3))
                    .andExpect(jsonPath("$.data.sourceQuizNumber").value(3))
                    .andExpect(jsonPath("$.data.difficulty").value("MEDIUM"))
                    .andExpect(jsonPath("$.data.question").value("정렬되어 있지 않은 배열이라면 어떻게 찾아야 할까?"))
                    .andExpect(jsonPath("$.data.oneLineAnswer.text").value("정렬이 안 됐다면 선형 탐색이 기본입니다."))
                    .andExpect(jsonPath("$.data.oneLineAnswer.highlights[0].keyword")
                            .value("선형 탐색"))
                    .andExpect(jsonPath("$.data.blocks[0].label").value("해설"))
                    .andExpect(jsonPath("$.data.blocks[0].type").value("TEXT"))
                    .andExpect(jsonPath("$.data.blocks[0].content.text").value("선형 탐색은 O(n)이다."))
                    .andExpect(jsonPath("$.data.keywords[0].keyword").value("선형 탐색"));
        }

        @Test
        @DisplayName("세션 진행도는 담지 않는다 — FE가 앞선 화면에서 들고 온다")
        void does_not_expose_session_progress() throws Exception {
            given(quizFollowUpQuestionService.getDetail(eq(FOLLOW_UP_QUESTION_ID)))
                    .willReturn(detailResponse());

            mockMvc.perform(get("/api/v1/follow-up-questions/{followUpQuestionId}", FOLLOW_UP_QUESTION_ID))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.currentNumber").doesNotExist())
                    .andExpect(jsonPath("$.data.totalCount").doesNotExist());
        }

        @Test
        @DisplayName("존재하지 않는 꼬리질문이면 404 FOLLOW_UP_QUESTION_NOT_FOUND")
        void returns_404_when_absent() throws Exception {
            given(quizFollowUpQuestionService.getDetail(eq(ABSENT_ID)))
                    .willThrow(new BusinessException(QuizErrorType.FOLLOW_UP_QUESTION_NOT_FOUND));

            mockMvc.perform(get("/api/v1/follow-up-questions/{followUpQuestionId}", ABSENT_ID))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.code").value("FOLLOW_UP_QUESTION_NOT_FOUND"))
                    .andExpect(jsonPath("$.data").isEmpty());
        }

        @Test
        @DisplayName("상세가 저작되지 않았으면 404 FOLLOW_UP_DETAIL_NOT_FOUND")
        void returns_404_when_detail_is_absent() throws Exception {
            given(quizFollowUpQuestionService.getDetail(eq(FOLLOW_UP_QUESTION_ID)))
                    .willThrow(new BusinessException(QuizErrorType.FOLLOW_UP_DETAIL_NOT_FOUND));

            mockMvc.perform(get("/api/v1/follow-up-questions/{followUpQuestionId}", FOLLOW_UP_QUESTION_ID))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.code").value("FOLLOW_UP_DETAIL_NOT_FOUND"));
        }
    }
}
