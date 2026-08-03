package studio.thumbsup.server.quiz;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.method.annotation.AuthenticationPrincipalArgumentResolver;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.validation.beanvalidation.MethodValidationInterceptor;
import studio.thumbsup.server.common.exception.GlobalExceptionHandler;
import studio.thumbsup.server.common.response.CursorMeta;
import studio.thumbsup.server.common.response.CursorPage;
import studio.thumbsup.server.quiz.dto.QuizAttemptHistoryResponse;
import studio.thumbsup.server.quiz.dto.QuizAttemptHistoryResponse.QuizAttemptHistoryItem;

/**
 * {@link QuizControllerTest}에서 분리 — 파일당 400줄 제한(checkstyle FileLength)에 맞춰
 * "내 풀이 기록 조회"(#261) 관련 테스트만 모았다. Controller 슬라이스 테스트(피라미드 2층).
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("내 풀이 기록 조회")
class QuizAttemptHistoryControllerTest {

    @Mock
    private QuizService quizService;

    private MockMvc mockMvc;
    private final ObjectMapper objectMapper = new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

    @BeforeEach
    void setUp() {
        // ProxyFactory + MethodValidationInterceptor: @Validated 메서드 파라미터(size의 @Min/@Max) 검증은
        // 운영에서 AOP가 하는데, standalone은 Boot 자동설정이 없어 직접 재현해야 한다.
        ProxyFactory proxyFactory = new ProxyFactory(new QuizController(quizService));
        proxyFactory.addAdvice(new MethodValidationInterceptor());
        Object controller = proxyFactory.getProxy();

        mockMvc = MockMvcBuilders.standaloneSetup(controller)
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
    @DisplayName("목록 조회")
    class GetAttemptHistory {

        @Test
        @DisplayName("목록 응답은 공통 envelope와 커서 meta를 따른다")
        void returns_common_envelope_with_cursor_meta() throws Exception {
            authenticateAs(7L);
            QuizAttemptHistoryItem item = new QuizAttemptHistoryItem(
                    5L,
                    1L,
                    QuizType.OX,
                    "TCP는 연결 지향 프로토콜이다.",
                    "O",
                    true,
                    OffsetDateTime.of(2026, 7, 7, 9, 0, 0, 0, ZoneOffset.ofHours(9)));
            given(quizService.getAttemptHistory(eq(7L), isNull(), eq(20)))
                    .willReturn(new CursorPage<>(
                            new QuizAttemptHistoryResponse(List.of(item)), CursorMeta.of(true, "cursor-5")));

            mockMvc.perform(get("/api/v1/quizzes/attempts"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.items[0].attemptId").value(5))
                    .andExpect(jsonPath("$.data.items[0].quizId").value(1))
                    .andExpect(jsonPath("$.data.items[0].type").value("OX"))
                    .andExpect(jsonPath("$.data.items[0].questionText").value("TCP는 연결 지향 프로토콜이다."))
                    .andExpect(jsonPath("$.data.items[0].selectedAnswer").value("O"))
                    .andExpect(jsonPath("$.data.items[0].isCorrect").value(true))
                    .andExpect(jsonPath("$.data.items[0].submittedAt").value("2026-07-07T09:00:00+09:00"))
                    .andExpect(jsonPath("$.meta.hasNext").value(true))
                    .andExpect(jsonPath("$.meta.nextCursor").value("cursor-5"));
        }

        @Test
        @DisplayName("size가 최대치를 넘으면 400 INVALID_INPUT")
        void returns_400_when_size_too_large() throws Exception {
            authenticateAs(7L);

            mockMvc.perform(get("/api/v1/quizzes/attempts").param("size", "200"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("INVALID_INPUT"));
        }
    }
}
