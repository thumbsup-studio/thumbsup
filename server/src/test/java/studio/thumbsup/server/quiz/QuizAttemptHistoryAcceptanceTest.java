package studio.thumbsup.server.quiz;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.HttpHeaders;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.security.JwtTokenProvider;

/**
 * 풀이 기록 조회 API 인수 테스트(#261) — 저장된 풀이 시도가 인증 필터체인·실제 MySQL 커서 페이지네이션·
 * 공통 응답 계약을 거쳐 노출되는지 검증한다 (피라미드 4층). 페이지네이션 경계·선택한 답 표시 변환은
 * {@code QuizAttemptHistoryServiceTest}가, 요청 검증(size 범위)은 {@code QuizControllerTest}도 함께 다루지만
 * 여기서는 인증 필터체인과 실 DB를 통과한 최종 계약만 확인한다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@ActiveProfiles("test")
class QuizAttemptHistoryAcceptanceTest {

    private static final long TEST_USER_ID = 501L;
    private static final long OTHER_USER_ID = 502L;
    private static final long USER_WITHOUT_ATTEMPTS_ID = 503L;

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final MockMvc mockMvc;
    private final ObjectMapper objectMapper;
    private final JwtTokenProvider jwtTokenProvider;
    private final QuizRepository quizRepository;
    private final QuizAttemptRepository quizAttemptRepository;

    QuizAttemptHistoryAcceptanceTest(
            @Autowired MockMvc mockMvc,
            @Autowired ObjectMapper objectMapper,
            @Autowired JwtTokenProvider jwtTokenProvider,
            @Autowired QuizRepository quizRepository,
            @Autowired QuizAttemptRepository quizAttemptRepository) {
        this.mockMvc = mockMvc;
        this.objectMapper = objectMapper;
        this.jwtTokenProvider = jwtTokenProvider;
        this.quizRepository = quizRepository;
        this.quizAttemptRepository = quizAttemptRepository;
    }

    private Quiz quiz;
    private Long oldestAttemptId;
    private Long newestAttemptId;

    @BeforeEach
    void seedAttempts() {
        // 이 클래스는 @Transactional이 없어 저장 행이 남으므로 매 테스트마다 초기화한다(시드가 없는 테이블).
        quizAttemptRepository.deleteAll();
        quiz = quizRepository.save(QuizFixture.oxQuiz());
        oldestAttemptId = quizAttemptRepository
                .save(QuizAttempt.create(quiz, TEST_USER_ID, true, "O"))
                .getId();
        quizAttemptRepository.save(QuizAttempt.create(quiz, TEST_USER_ID, false, "X"));
        newestAttemptId = quizAttemptRepository
                .save(QuizAttempt.create(quiz, TEST_USER_ID, true, "O"))
                .getId();
        quizAttemptRepository.save(QuizAttempt.create(quiz, OTHER_USER_ID, true, "O")); // 다른 유저 — 섞이면 안 됨
    }

    private String bearerToken(long userId) {
        return "Bearer " + jwtTokenProvider.createAccessToken(userId);
    }

    @Nested
    @DisplayName("GET /api/v1/quizzes/attempts")
    class GetAttemptHistory {

        @Test
        @DisplayName("공통 envelope와 커서 meta로 최신순 목록을 반환한다")
        void returns_attempts_in_id_desc_with_cursor_meta() throws Exception {
            mockMvc.perform(get("/api/v1/quizzes/attempts")
                            .param("size", "2")
                            .header(HttpHeaders.AUTHORIZATION, bearerToken(TEST_USER_ID)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.items.length()").value(2))
                    .andExpect(jsonPath("$.data.items[0].attemptId").value(newestAttemptId))
                    .andExpect(jsonPath("$.data.items[0].questionText").value(quiz.getQuestionText()))
                    .andExpect(jsonPath("$.data.items[0].selectedAnswer").value("O"))
                    .andExpect(jsonPath("$.data.items[0].isCorrect").value(true))
                    .andExpect(jsonPath("$.meta.hasNext").value(true))
                    .andExpect(jsonPath("$.meta.nextCursor").isNotEmpty());
        }

        @Test
        @DisplayName("nextCursor로 이어서 조회하면 남은 항목이 내려오고 hasNext는 false다")
        void follows_cursor_to_next_page() throws Exception {
            String firstPage = mockMvc.perform(get("/api/v1/quizzes/attempts")
                            .param("size", "2")
                            .header(HttpHeaders.AUTHORIZATION, bearerToken(TEST_USER_ID)))
                    .andExpect(status().isOk())
                    .andReturn()
                    .getResponse()
                    .getContentAsString(StandardCharsets.UTF_8);
            String nextCursor = objectMapper
                    .readTree(firstPage)
                    .path("meta")
                    .path("nextCursor")
                    .asText();

            mockMvc.perform(get("/api/v1/quizzes/attempts")
                            .param("size", "2")
                            .param("cursor", nextCursor)
                            .header(HttpHeaders.AUTHORIZATION, bearerToken(TEST_USER_ID)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.items.length()").value(1))
                    .andExpect(jsonPath("$.data.items[0].attemptId").value(oldestAttemptId))
                    .andExpect(jsonPath("$.meta.hasNext").value(false));
        }

        @Test
        @DisplayName("다른 유저의 풀이 기록은 섞이지 않는다")
        void does_not_leak_other_users_attempts() throws Exception {
            mockMvc.perform(get("/api/v1/quizzes/attempts")
                            .param("size", "10")
                            .header(HttpHeaders.AUTHORIZATION, bearerToken(TEST_USER_ID)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.items.length()").value(3));
        }

        @Test
        @DisplayName("아직 하나도 풀지 않은 유저는 빈 목록을 반환한다")
        void returns_empty_list_for_user_without_attempts() throws Exception {
            mockMvc.perform(get("/api/v1/quizzes/attempts")
                            .header(HttpHeaders.AUTHORIZATION, bearerToken(USER_WITHOUT_ATTEMPTS_ID)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.items.length()").value(0))
                    .andExpect(jsonPath("$.meta.hasNext").value(false));
        }

        @Test
        @DisplayName("size가 최대치를 넘으면 400 INVALID_INPUT으로 막는다")
        void rejects_too_large_size() throws Exception {
            mockMvc.perform(get("/api/v1/quizzes/attempts")
                            .param("size", "200")
                            .header(HttpHeaders.AUTHORIZATION, bearerToken(TEST_USER_ID)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("INVALID_INPUT"));
        }

        @Test
        @DisplayName("Authorization 헤더가 없으면 필터체인이 401로 막는다")
        void returns_401_without_token() throws Exception {
            mockMvc.perform(get("/api/v1/quizzes/attempts")).andExpect(status().isUnauthorized());
        }
    }
}
