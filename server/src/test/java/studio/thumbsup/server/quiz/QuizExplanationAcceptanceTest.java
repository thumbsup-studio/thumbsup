package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.test.web.servlet.MockMvc;
import studio.thumbsup.server.common.security.JwtTokenProvider;
import studio.thumbsup.server.common.support.AcceptanceTestSupport;

/**
 * 해설 조회 API(#43) 인수 테스트 — Flyway 시드를 실제 MySQL에 올리고 필터체인까지 통과시켜
 * "해설 화면(S4)이 필요한 데이터를 한 번에 받는가"를 검증한다.
 *
 * <p>docs/testing-guide.md §3 기준으로 인수 층에 두는 이유: 필터체인에서 막히는 인증 동작 +
 * Flyway 시드에 저작된 {@code [[마커]]}가 JPA를 거쳐 하이라이트 구간으로 변환되는 흐름 +
 * 깨지면 FE 계약에 바로 영향을 주는 흐름이기 때문이다. 마커 파싱의 분기(미등록 마커·중첩 등)는
 * {@link ExplanationTextParserTest}가, 응답 조립 규칙은 {@code QuizServiceTest}가 담당한다.
 */
class QuizExplanationAcceptanceTest extends AcceptanceTestSupport {

    private static final long TEST_USER_ID = 999L;
    private static final int FORMAL_STEP_ORDER = 1;
    private static final int PROCESS_STEP_ORDER = 2;
    /** 픽스처 전용 스텝 — 시드가 쓰는 어떤 스텝과도 겹치지 않는다(server/docs 관례: 101/102). */
    private static final int FIXTURE_STEP_ORDER = 101;
    /** 커리큘럼 밖 3문제 스텝 — #287에서 지워진 시드 placeholder를 대체하는 픽스처 전용 스텝. */
    private static final int PLACEHOLDER_STEP_ORDER = 102;

    private static final long ABSENT_QUIZ_ID = 999_999L;

    private final MockMvc mockMvc;
    private final JwtTokenProvider jwtTokenProvider;
    private final ObjectMapper objectMapper;
    private final QuizRepository quizRepository;
    private final QuizStepRepository quizStepRepository;

    QuizExplanationAcceptanceTest(
            @Autowired MockMvc mockMvc,
            @Autowired JwtTokenProvider jwtTokenProvider,
            @Autowired ObjectMapper objectMapper,
            @Autowired QuizRepository quizRepository,
            @Autowired QuizStepRepository quizStepRepository) {
        this.mockMvc = mockMvc;
        this.jwtTokenProvider = jwtTokenProvider;
        this.objectMapper = objectMapper;
        this.quizRepository = quizRepository;
        this.quizStepRepository = quizStepRepository;
    }

    private String bearerToken() {
        return "Bearer " + jwtTokenProvider.createAccessToken(TEST_USER_ID);
    }

    /** placeholder(id=1)가 아니라 정식 커리큘럼 1스텝의 첫 OX 문제를 조회한다. */
    private Quiz seededOxQuiz() {
        return quizRepository.findByStepOrderOrderBySlotOrderAsc(FORMAL_STEP_ORDER).stream()
                .filter(quiz -> quiz.getSlotOrder() == 1 && quiz.getType() == QuizType.OX)
                .findFirst()
                .orElseThrow();
    }

    /** QA에서 동일 키워드가 세 영역에 중복 강조된 프로세스·문맥 전환 문제. */
    private Quiz seededContextSwitchQuiz() {
        return quizRepository.findByStepOrderOrderBySlotOrderAsc(PROCESS_STEP_ORDER).stream()
                .filter(quiz -> quiz.getSlotOrder() == 5 && quiz.getType() == QuizType.KEYWORD_BLANK)
                .findFirst()
                .orElseThrow();
    }

    /**
     * 커리큘럼 밖 3문제 스텝을 직접 만든다 — #287에서 지운 시드 placeholder(step_order=0)를 대체한다.
     * 1번 슬롯 문제는 꼬리질문 상세와, 오답 해설에만 등장하는 키워드("비연결형")를 갖는다.
     * 여러 테스트가 호출하므로(이 클래스는 {@code @Transactional}이 없다) 이미 만들어졌으면 재사용한다.
     */
    private Quiz placeholderQuiz() {
        Optional<Quiz> existing = quizRepository.findByStepOrderAndSlotOrder(PLACEHOLDER_STEP_ORDER, 1);
        if (existing.isPresent()) {
            return existing.get();
        }

        quizStepRepository.save(QuizStep.create(PLACEHOLDER_STEP_ORDER, 1L, "픽스처 스텝", 3));

        // 하이라이트는 [[마커]]로 본문에 직접 저작된 구간만 변환되므로(QuizFixture.oxQuiz()는 마커가 없다),
        // "비연결형"을 오답 해설에만 마커로 넣어 요약에는 없는 키워드 하이라이트를 재현한다.
        Quiz first = Quiz.create(
                QuizType.OX,
                QuizDifficulty.EASY,
                "TCP는 연결 지향 프로토콜이다.",
                null,
                "TCP는 3-way handshake로 연결을 맺는 연결 지향 프로토콜이다.",
                null,
                "UDP와 헷갈리기 쉽다 — UDP는 [[비연결형]]이라 handshake가 없다.");
        first.assignCorrectAnswer("O");
        first.addFollowUpQuestion("UDP와 TCP의 핵심 차이는 무엇인가요?", true, 1)
                .attachDetail(QuizDifficulty.EASY, "UDP와 TCP의 가장 큰 차이는 연결 여부다.");
        first.addKeyword("비연결형", "연결을 수립하지 않고 곧바로 전송하는 방식");
        first.assignPosition(PLACEHOLDER_STEP_ORDER, 1);
        Quiz saved = quizRepository.save(first);

        Quiz second = QuizFixture.multipleChoiceQuiz();
        second.assignPosition(PLACEHOLDER_STEP_ORDER, 2);
        quizRepository.save(second);

        Quiz third = QuizFixture.keywordBlankQuiz();
        third.assignPosition(PLACEHOLDER_STEP_ORDER, 3);
        quizRepository.saveAndFlush(third);

        return saved;
    }

    /**
     * 상세 없는 꼬리질문을 가진 문제를 직접 만든다 — 시드에는 더 이상 그런 꼬리질문이 없다(#133 백필).
     *
     * <p>이 클래스는 {@code @Transactional}이 없어 저장한 행이 남는다. 시드가 쓰는 스텝에 끼워 넣으면
     * {@code countByStepOrder}로 계산되는 {@code totalCount} 단언이 실행 순서에 따라 흔들린다 —
     * 그래서 커리큘럼 밖 스텝을 따로 만든다.
     */
    private Quiz quizWithUndetailedFollowUpQuestion() {
        // quiz.step_order가 quiz_step.step_order를 FK로 참조하므로 스텝 행이 먼저 있어야 한다.
        quizStepRepository
                .findByStepOrder(FIXTURE_STEP_ORDER)
                .orElseGet(() -> quizStepRepository.save(QuizStep.create(FIXTURE_STEP_ORDER, 1L, "픽스처 스텝", 3)));

        Quiz quiz = QuizFixture.oxQuiz();
        quiz.assignPosition(FIXTURE_STEP_ORDER, 1);
        return quizRepository.saveAndFlush(quiz);
    }

    private JsonNode fetchExplanationData(long quizId) throws Exception {
        String body = mockMvc.perform(get("/api/v1/quizzes/{quizId}/explanation", quizId)
                        .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        return objectMapper.readTree(body).path("data");
    }

    /** 응답에 담긴 모든 주석 텍스트(해설 3줄 + 예시 + 오답 해설)를 한 곳에 모은다. */
    private static List<JsonNode> annotatedTexts(JsonNode data) {
        List<JsonNode> texts = new ArrayList<>();
        data.path("explanationSummary").forEach(texts::add);
        for (String field : List.of("explanationExample", "wrongAnswerExplanation")) {
            JsonNode node = data.path(field);
            if (node.isObject()) {
                texts.add(node);
            }
        }
        return texts;
    }

    @Nested
    @DisplayName("GET /api/v1/quizzes/{quizId}/explanation")
    class GetExplanation {

        @Test
        @DisplayName("문제 맥락·해설·키워드 설명을 한 번의 호출로 반환한다")
        void returns_full_explanation_payload() throws Exception {
            Quiz quiz = seededOxQuiz();

            mockMvc.perform(get("/api/v1/quizzes/{quizId}/explanation", quiz.getId())
                            .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.quizId").value(quiz.getId()))
                    .andExpect(jsonPath("$.data.questionText").value(quiz.getQuestionText()))
                    .andExpect(jsonPath("$.data.type").value(quiz.getType().name()))
                    .andExpect(jsonPath("$.data.difficulty")
                            .value(quiz.getDifficulty().name()))
                    .andExpect(jsonPath("$.data.currentNumber").value(quiz.getSlotOrder()))
                    .andExpect(jsonPath("$.data.totalCount").value(5))
                    .andExpect(jsonPath("$.data.courseTitle").value("운영체제"))
                    .andExpect(jsonPath("$.data.unitTitle").value("OS 개요와 역할(커널·시스템콜·인터럽트)"))
                    .andExpect(jsonPath("$.data.keywords[0].keyword").value("커널"))
                    .andExpect(jsonPath("$.data.keywords[0].description").isNotEmpty())
                    .andExpect(jsonPath("$.data.wrongAnswerExplanation.text").isNotEmpty());
        }

        @Test
        @DisplayName("상세 콘텐츠가 저작되지 않은 꼬리질문은 응답에서 제외된다 — 탭해도 그릴 것이 없기 때문")
        void omits_follow_up_questions_without_detail() throws Exception {
            JsonNode data =
                    fetchExplanationData(quizWithUndetailedFollowUpQuestion().getId());

            assertThat(data.path("followUpQuestions").isArray()).isTrue();
            assertThat(data.path("followUpQuestions").size()).isZero();
        }

        @Test
        @DisplayName("커리큘럼 문제는 백필(#133)된 꼬리질문 2건을 대표 질문부터 내려준다")
        void exposes_backfilled_follow_up_questions_of_the_curriculum() throws Exception {
            JsonNode followUpQuestions =
                    fetchExplanationData(seededOxQuiz().getId()).path("followUpQuestions");

            assertThat(followUpQuestions.size()).isEqualTo(2);
            assertThat(followUpQuestions.path(0).path("isPrimary").asBoolean()).isTrue();
            assertThat(followUpQuestions.path(1).path("isPrimary").asBoolean()).isFalse();
            followUpQuestions.forEach(followUpQuestion -> {
                assertThat(followUpQuestion.path("followUpQuestionId").asLong()).isPositive();
                assertThat(followUpQuestion.path("content").asText()).doesNotContain("[[");
            });
        }

        @Test
        @DisplayName("상세가 저작된 꼬리질문은 상세 조회용 ID와 대표 여부를 함께 내려준다")
        void exposes_follow_up_question_id_for_routing() throws Exception {
            JsonNode followUpQuestion = fetchExplanationData(placeholderQuiz().getId())
                    .path("followUpQuestions")
                    .path(0);

            assertThat(followUpQuestion.path("followUpQuestionId").asLong()).isPositive();
            assertThat(followUpQuestion.path("content").asText()).isNotBlank();
            assertThat(followUpQuestion.path("isPrimary").asBoolean()).isTrue();
        }

        @Test
        @DisplayName("핵심 정리는 개행 기준으로 나뉜 여러 줄로 내려간다 (핵심 N줄 정리 UI용)")
        void returns_summary_split_into_lines() throws Exception {
            mockMvc.perform(get(
                                    "/api/v1/quizzes/{quizId}/explanation",
                                    seededOxQuiz().getId())
                            .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.explanationSummary").isArray())
                    .andExpect(jsonPath("$.data.explanationSummary.length()").value(3))
                    .andExpect(jsonPath("$.data.explanationSummary[0].text").isNotEmpty())
                    .andExpect(jsonPath("$.data.explanationSummary[0].highlights[0].keyword")
                            .value("커널"));
        }

        @Test
        @DisplayName("본문에서 마커는 제거되고, 하이라이트 구간이 정확히 그 키워드를 가리킨다")
        void strips_markers_and_anchors_highlights() throws Exception {
            JsonNode data = fetchExplanationData(seededOxQuiz().getId());

            List<JsonNode> texts = annotatedTexts(data);
            assertThat(texts).isNotEmpty();

            int highlightCount = 0;
            for (JsonNode annotated : texts) {
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
        @DisplayName("같은 키워드는 해설 세 영역 전체에서 한 번만 하이라이트된다")
        void highlights_each_keyword_once_across_all_explanation_fields() throws Exception {
            JsonNode data = fetchExplanationData(seededContextSwitchQuiz().getId());

            List<JsonNode> contextSwitchHighlights = annotatedTexts(data).stream()
                    .flatMap(annotated -> {
                        List<JsonNode> highlights = new ArrayList<>();
                        annotated.path("highlights").forEach(highlights::add);
                        return highlights.stream();
                    })
                    .filter(highlight ->
                            "문맥 전환".equals(highlight.path("keyword").asText()))
                    .toList();

            assertThat(contextSwitchHighlights).hasSize(1);
            JsonNode summary = data.path("explanationSummary").path(0);
            JsonNode highlight = summary.path("highlights").path(0);
            assertThat(highlight.path("keyword").asText()).isEqualTo("문맥 전환");
            assertThat(summary.path("text")
                            .asText()
                            .substring(
                                    highlight.path("start").asInt(),
                                    highlight.path("end").asInt()))
                    .isEqualTo("문맥 전환");
        }

        @Test
        @DisplayName("요약에 없는 키워드는 오답 해설에서 한 번 하이라이트된다")
        void highlights_keyword_authored_only_in_wrong_answer_explanation() throws Exception {
            JsonNode data = fetchExplanationData(placeholderQuiz().getId());

            List<String> wrongAnswerKeywords = new ArrayList<>();
            data.path("wrongAnswerExplanation")
                    .path("highlights")
                    .forEach(highlight ->
                            wrongAnswerKeywords.add(highlight.path("keyword").asText()));

            assertThat(wrongAnswerKeywords).containsExactly("비연결형");
        }

        @Test
        @DisplayName("기존 placeholder 문제도 순번과 전체 개수를 포함한 해설을 반환한다")
        void returns_explanation_for_placeholder_quiz() throws Exception {
            Quiz placeholder = placeholderQuiz();

            mockMvc.perform(get("/api/v1/quizzes/{quizId}/explanation", placeholder.getId())
                            .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.explanationExample").isEmpty())
                    .andExpect(jsonPath("$.data.currentNumber").value(1))
                    .andExpect(jsonPath("$.data.totalCount").value(3));
        }

        @Test
        @DisplayName("채점 결과와 정답은 담지 않는다 — 정답 확인 API(#42)의 몫이다")
        void does_not_expose_grading_result() throws Exception {
            mockMvc.perform(get(
                                    "/api/v1/quizzes/{quizId}/explanation",
                                    seededOxQuiz().getId())
                            .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.isCorrect").doesNotExist())
                    .andExpect(jsonPath("$.data.correctAnswer").doesNotExist());
        }

        @Test
        @DisplayName("존재하지 않는 문제면 404 QUIZ_NOT_FOUND를 반환한다")
        void returns_404_when_quiz_is_absent() throws Exception {
            mockMvc.perform(get("/api/v1/quizzes/{quizId}/explanation", ABSENT_QUIZ_ID)
                            .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.code").value("QUIZ_NOT_FOUND"));
        }

        @Test
        @DisplayName("Authorization 헤더가 없으면 필터체인이 401로 막는다")
        void returns_401_without_token() throws Exception {
            mockMvc.perform(get(
                            "/api/v1/quizzes/{quizId}/explanation",
                            seededOxQuiz().getId()))
                    .andExpect(status().isUnauthorized());
        }
    }
}
