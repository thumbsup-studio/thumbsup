package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
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
 * 꼬리질문 상세 조회 API(#108) 인수 테스트 — 해설 응답에서 받은 followUpQuestionId로 곧바로
 * 꼬리질문 화면을 그릴 수 있는가를, Flyway 시드와 필터체인까지 통과시켜 검증한다.
 *
 * <p>이 흐름이 깨지면 FE가 꼬리질문을 탭해도 갈 곳이 없다. 마커 파싱의 분기는
 * {@link ExplanationTextParserTest}가, 응답 조립 규칙은 {@link QuizFollowUpQuestionServiceTest}가 담당한다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@ActiveProfiles("test")
class FollowUpQuestionAcceptanceTest {

    private static final long TEST_USER_ID = 999L;
    private static final long ABSENT_FOLLOW_UP_QUESTION_ID = 999_999L;
    /** 샘플 문제(커리큘럼 밖)가 사는 스텝. 정식 커리큘럼은 1부터다. */
    private static final int SAMPLE_STEP_ORDER = 0;
    /** 픽스처 전용 스텝 — 시드가 쓰는 어떤 스텝과도 겹치지 않는다(server/docs 관례: 101/102). */
    private static final int FIXTURE_STEP_ORDER = 101;

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final MockMvc mockMvc;
    private final JwtTokenProvider jwtTokenProvider;
    private final ObjectMapper objectMapper;
    private final QuizRepository quizRepository;
    private final QuizFollowUpQuestionRepository quizFollowUpQuestionRepository;
    private final QuizStepRepository quizStepRepository;

    FollowUpQuestionAcceptanceTest(
            @Autowired MockMvc mockMvc,
            @Autowired JwtTokenProvider jwtTokenProvider,
            @Autowired ObjectMapper objectMapper,
            @Autowired QuizRepository quizRepository,
            @Autowired QuizFollowUpQuestionRepository quizFollowUpQuestionRepository,
            @Autowired QuizStepRepository quizStepRepository) {
        this.mockMvc = mockMvc;
        this.jwtTokenProvider = jwtTokenProvider;
        this.objectMapper = objectMapper;
        this.quizRepository = quizRepository;
        this.quizFollowUpQuestionRepository = quizFollowUpQuestionRepository;
        this.quizStepRepository = quizStepRepository;
    }

    private String bearerToken() {
        return "Bearer " + jwtTokenProvider.createAccessToken(TEST_USER_ID);
    }

    /** 해설 응답이 실제로 내려준 ID를 그대로 쓴다 — 두 API가 이어지는지가 이 테스트의 핵심이다. */
    private long primaryFollowUpQuestionId() throws Exception {
        long sampleQuizId = quizRepository.findByStepOrderOrderBySlotOrderAsc(SAMPLE_STEP_ORDER).stream()
                .findFirst()
                .orElseThrow()
                .getId();

        String body = mockMvc.perform(get("/api/v1/quizzes/{quizId}/explanation", sampleQuizId)
                        .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);

        return objectMapper
                .readTree(body)
                .path("data")
                .path("followUpQuestions")
                .path(0)
                .path("followUpQuestionId")
                .asLong();
    }

    /**
     * 상세가 없는 꼬리질문을 직접 만든다 — 시드에서 주워 쓰지 않는다.
     * 커리큘럼 120건을 백필(#133)한 뒤로 시드에는 상세 없는 꼬리질문이 하나도 남아 있지 않다.
     *
     * <p>이 클래스는 {@code @Transactional}이 없어 저장한 행이 남는다. 시드가 쓰는 스텝을 건드리지 않도록
     * 커리큘럼 밖 스텝을 따로 만든다 — 문제 수를 세는 단언이 실행 순서에 따라 흔들리지 않게.
     */
    private long followUpQuestionIdWithoutDetail() {
        // quiz.step_order가 quiz_step.step_order를 FK로 참조하므로 스텝 행이 먼저 있어야 한다.
        quizStepRepository
                .findByStepOrder(FIXTURE_STEP_ORDER)
                .orElseGet(() -> quizStepRepository.save(QuizStep.create(FIXTURE_STEP_ORDER, 1L, "픽스처 스텝", 3)));

        Quiz quiz = QuizFixture.oxQuiz();
        quiz.assignPosition(FIXTURE_STEP_ORDER, 1);
        return quizRepository.saveAndFlush(quiz).getFollowUpQuestions().get(0).getId();
    }

    private JsonNode fetchDetailData(long followUpQuestionId) throws Exception {
        String body = mockMvc.perform(get("/api/v1/follow-up-questions/{id}", followUpQuestionId)
                        .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        return objectMapper.readTree(body).path("data");
    }

    @Nested
    @DisplayName("GET /api/v1/follow-up-questions/{followUpQuestionId}")
    class GetFollowUpQuestion {

        @Test
        @DisplayName("해설 응답이 내려준 ID로 꼬리질문 화면 콘텐츠를 한 번에 받는다")
        void returns_detail_for_id_taken_from_explanation() throws Exception {
            JsonNode data = fetchDetailData(primaryFollowUpQuestionId());

            assertThat(data.path("sourceQuizId").asLong()).isPositive();
            assertThat(data.path("sourceQuizNumber").asInt()).isPositive();
            assertThat(data.path("difficulty").asText()).isIn("EASY", "MEDIUM", "HARD");
            assertThat(data.path("question").asText()).isNotBlank();
            assertThat(data.path("oneLineAnswer").path("text").asText()).isNotBlank();
            assertThat(data.path("blocks").size()).isPositive();
            assertThat(data.path("keywords").size()).isPositive();
        }

        @Test
        @DisplayName("본문에서 마커는 제거되고, 하이라이트 구간이 정확히 그 키워드를 가리킨다")
        void strips_markers_and_anchors_highlights() throws Exception {
            JsonNode data = fetchDetailData(primaryFollowUpQuestionId());

            List<JsonNode> annotatedTexts = new ArrayList<>();
            annotatedTexts.add(data.path("oneLineAnswer"));
            data.path("blocks").forEach(block -> annotatedTexts.add(block.path("content")));

            int highlightCount = 0;
            for (JsonNode annotated : annotatedTexts) {
                String text = annotated.path("text").asText();
                assertThat(text).doesNotContain("[[").doesNotContain("]]");

                for (JsonNode highlight : annotated.path("highlights")) {
                    int start = highlight.path("start").asInt();
                    int end = highlight.path("end").asInt();
                    assertThat(text.substring(start, end))
                            .isEqualTo(highlight.path("keyword").asText());
                    highlightCount++;
                }
            }
            assertThat(highlightCount).isPositive();
        }

        @Test
        @DisplayName("하이라이트에 쓰인 키워드는 모두 키워드 사전에 존재한다")
        void every_highlighted_keyword_exists_in_the_dictionary() throws Exception {
            JsonNode data = fetchDetailData(primaryFollowUpQuestionId());

            List<String> dictionary = new ArrayList<>();
            data.path("keywords")
                    .forEach(keyword -> dictionary.add(keyword.path("keyword").asText()));

            List<String> highlighted = new ArrayList<>();
            data.path("oneLineAnswer")
                    .path("highlights")
                    .forEach(highlight ->
                            highlighted.add(highlight.path("keyword").asText()));
            data.path("blocks").forEach(block -> block.path("content")
                    .path("highlights")
                    .forEach(highlight ->
                            highlighted.add(highlight.path("keyword").asText())));

            assertThat(highlighted).isNotEmpty();
            assertThat(dictionary).containsAll(highlighted);
        }

        @Test
        @DisplayName("모든 시드 꼬리질문은 등록 키워드를 한 줄 답과 전체 블록에서 정확히 한 번만 하이라이트한다")
        void highlights_each_keyword_once_across_every_authored_field() throws Exception {
            List<Long> detailedFollowUpQuestionIds = quizFollowUpQuestionRepository.findAll().stream()
                    .filter(QuizFollowUpQuestion::hasDetail)
                    .map(QuizFollowUpQuestion::getId)
                    .toList();
            assertThat(detailedFollowUpQuestionIds).hasSizeGreaterThanOrEqualTo(123);

            List<String> violations = new ArrayList<>();
            for (Long followUpQuestionId : detailedFollowUpQuestionIds) {
                collectHighlightViolations(followUpQuestionId, fetchDetailData(followUpQuestionId), violations);
            }

            assertThat(violations).as("꼬리질문 API 하이라이트 전수 검사 위반 목록").isEmpty();
        }

        @Test
        @DisplayName("상세가 저작되지 않은 꼬리질문이면 404 FOLLOW_UP_DETAIL_NOT_FOUND — 새 문제를 생성했는데 상세를 빠뜨린 경우")
        void returns_404_when_detail_is_not_authored_yet() throws Exception {
            mockMvc.perform(get("/api/v1/follow-up-questions/{id}", followUpQuestionIdWithoutDetail())
                            .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.code").value("FOLLOW_UP_DETAIL_NOT_FOUND"));
        }

        @Test
        @DisplayName("존재하지 않는 꼬리질문이면 404 FOLLOW_UP_QUESTION_NOT_FOUND")
        void returns_404_when_follow_up_question_is_absent() throws Exception {
            mockMvc.perform(get("/api/v1/follow-up-questions/{id}", ABSENT_FOLLOW_UP_QUESTION_ID)
                            .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.code").value("FOLLOW_UP_QUESTION_NOT_FOUND"));
        }

        @Test
        @DisplayName("Authorization 헤더가 없으면 필터체인이 401로 막는다")
        void returns_401_without_token() throws Exception {
            mockMvc.perform(get("/api/v1/follow-up-questions/{id}", 1L)).andExpect(status().isUnauthorized());
        }

        private void collectHighlightViolations(Long followUpQuestionId, JsonNode data, List<String> violations) {
            List<String> dictionary = new ArrayList<>();
            data.path("keywords")
                    .forEach(keyword -> dictionary.add(keyword.path("keyword").asText()));

            List<JsonNode> annotatedTexts = new ArrayList<>();
            annotatedTexts.add(data.path("oneLineAnswer"));
            data.path("blocks").forEach(block -> annotatedTexts.add(block.path("content")));

            Map<String, Integer> highlightCounts = new HashMap<>();
            for (JsonNode annotated : annotatedTexts) {
                collectAnnotatedTextViolations(followUpQuestionId, annotated, dictionary, highlightCounts, violations);
            }

            for (String keyword : dictionary) {
                int count = highlightCounts.getOrDefault(keyword, 0);
                if (count != 1) {
                    violations.add(followUpQuestionId + ": " + keyword + " highlight " + count + "회");
                }
            }
        }

        private void collectAnnotatedTextViolations(
                Long followUpQuestionId,
                JsonNode annotated,
                List<String> dictionary,
                Map<String, Integer> highlightCounts,
                List<String> violations) {
            String text = annotated.path("text").asText();
            if (text.contains("[[") || text.contains("]]")) {
                violations.add(followUpQuestionId + ": 응답 평문에 marker 구분자 노출");
            }
            for (JsonNode highlight : annotated.path("highlights")) {
                collectSingleHighlightViolation(
                        followUpQuestionId, text, highlight, dictionary, highlightCounts, violations);
            }
        }

        private void collectSingleHighlightViolation(
                Long followUpQuestionId,
                String text,
                JsonNode highlight,
                List<String> dictionary,
                Map<String, Integer> highlightCounts,
                List<String> violations) {
            String keyword = highlight.path("keyword").asText();
            highlightCounts.merge(keyword, 1, Integer::sum);
            if (!dictionary.contains(keyword)) {
                violations.add(followUpQuestionId + ": 미등록 highlight " + keyword);
            }
            int start = highlight.path("start").asInt();
            int end = highlight.path("end").asInt();
            if (start < 0 || end > text.length() || start >= end) {
                violations.add(followUpQuestionId + ": 잘못된 highlight 구간 " + keyword);
            } else if (!text.substring(start, end).equals(keyword)) {
                violations.add(followUpQuestionId + ": highlight 구간 불일치 " + keyword);
            }
        }
    }
}
