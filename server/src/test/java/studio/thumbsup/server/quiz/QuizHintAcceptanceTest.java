package studio.thumbsup.server.quiz;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
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
import org.springframework.transaction.annotation.Transactional;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.security.JwtTokenProvider;

/** 풀이 중 요청형 힌트 API 인수 테스트 — 실제 Flyway 백필·JPA·JWT 필터체인을 함께 검증한다. */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@ActiveProfiles("test")
class QuizHintAcceptanceTest {

    private static final long TEST_USER_ID = 193_001L;
    private static final long OS_COURSE_ID = 1L;

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final MockMvc mockMvc;
    private final JwtTokenProvider jwtTokenProvider;
    private final QuizRepository quizRepository;
    private final QuizAttemptRepository quizAttemptRepository;
    private final QuizProgressRepository quizProgressRepository;

    QuizHintAcceptanceTest(
            @Autowired MockMvc mockMvc,
            @Autowired JwtTokenProvider jwtTokenProvider,
            @Autowired QuizRepository quizRepository,
            @Autowired QuizAttemptRepository quizAttemptRepository,
            @Autowired QuizProgressRepository quizProgressRepository) {
        this.mockMvc = mockMvc;
        this.jwtTokenProvider = jwtTokenProvider;
        this.quizRepository = quizRepository;
        this.quizAttemptRepository = quizAttemptRepository;
        this.quizProgressRepository = quizProgressRepository;
    }

    @BeforeEach
    void setUpProgress() {
        quizProgressRepository
                .findByUserIdAndCourseId(TEST_USER_ID, OS_COURSE_ID)
                .orElseGet(
                        () -> quizProgressRepository.saveAndFlush(QuizProgress.create(TEST_USER_ID, OS_COURSE_ID, 1)));
    }

    private String bearerToken() {
        return "Bearer " + jwtTokenProvider.createAccessToken(TEST_USER_ID);
    }

    private Quiz seededQuiz(int stepOrder, int slotOrder) {
        return quizRepository.findByStepOrderAndSlotOrder(stepOrder, slotOrder).orElseThrow();
    }

    @Nested
    @DisplayName("힌트 요청")
    class GetHint {

        @Test
        @DisplayName("OX·사지선다·빈칸 모두 단일 hint 문자열을 반환하고 풀이 이력을 만들지 않는다")
        void returns_one_sentence_hint_for_every_type_without_attempt_side_effect() throws Exception {
            List<Quiz> quizzes = List.of(seededQuiz(1, 1), seededQuiz(1, 3), seededQuiz(1, 5));
            int attemptsBefore = quizAttemptRepository
                    .findByUserIdAndQuiz_StepOrder(TEST_USER_ID, 1)
                    .size();

            for (Quiz quiz : quizzes) {
                mockMvc.perform(post("/api/v1/quizzes/{quizId}/hints", quiz.getId())
                                .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                        .andExpect(status().isOk())
                        .andExpect(jsonPath("$.code").value("SUCCESS"))
                        .andExpect(jsonPath("$.data.hint").isString())
                        .andExpect(jsonPath("$.data.hint").value(quiz.getHint()))
                        .andExpect(jsonPath("$.data.eliminatedChoiceId").doesNotExist())
                        .andExpect(jsonPath("$.data.blankHints").doesNotExist());
            }

            int attemptsAfter = quizAttemptRepository
                    .findByUserIdAndQuiz_StepOrder(TEST_USER_ID, 1)
                    .size();
            org.assertj.core.api.Assertions.assertThat(attemptsAfter).isEqualTo(attemptsBefore);
        }

        @Test
        @DisplayName("아직 진행하지 않은 미래 스텝의 힌트는 요청할 수 없다")
        void rejects_future_step() throws Exception {
            Quiz futureQuiz = seededQuiz(2, 1);

            mockMvc.perform(post("/api/v1/quizzes/{quizId}/hints", futureQuiz.getId())
                            .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.code").value("QUIZ_NOT_ACCESSIBLE"));
        }

        @Test
        @Transactional
        @DisplayName("canonical 백필에서 제외된 hint NULL 문제는 409를 반환한다")
        void returns_conflict_when_hint_was_not_backfilled() throws Exception {
            Quiz quiz = seededQuiz(1, 2);
            quiz.assignHint(null);
            quizRepository.saveAndFlush(quiz);

            mockMvc.perform(post("/api/v1/quizzes/{quizId}/hints", quiz.getId())
                            .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.code").value("QUIZ_HINT_NOT_AVAILABLE"));
        }

        @Test
        @DisplayName("인증 없이 힌트를 요청하면 401을 반환한다")
        void requires_authentication() throws Exception {
            Quiz quiz = seededQuiz(1, 1);

            mockMvc.perform(post("/api/v1/quizzes/{quizId}/hints", quiz.getId()))
                    .andExpect(status().isUnauthorized())
                    .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
        }
    }
}
