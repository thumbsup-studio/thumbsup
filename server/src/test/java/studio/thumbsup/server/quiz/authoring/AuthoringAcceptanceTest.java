package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.DatabaseCleanUp;
import studio.thumbsup.server.common.security.JwtTokenProvider;
import studio.thumbsup.server.quiz.Course;
import studio.thumbsup.server.quiz.CourseRepository;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture;

/**
 * 저작 파이프라인(#174) 인수 테스트 — 대시보드가 잡을 만들고, 브리지가 폴링·로그·결과를 제출하고,
 * 대시보드가 승인해 라이브 문제로 반영하기까지 전체 계약이 실제로 이어지는가를 검증한다.
 *
 * <p>{@code FollowUpQuestionAcceptanceTest}처럼 {@code @Transactional}을 켜지 않는다 — 승인 후
 * quiz 테이블에 실제로 행이 늘었는지(materialize)를 별도 조회로 증명해야 하기 때문이다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@ActiveProfiles("test")
class AuthoringAcceptanceTest {

    private static final long USER_ID = 900L;
    private static final long OTHER_USER_ID = 901L;

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final MockMvc mockMvc;
    private final JwtTokenProvider jwtTokenProvider;
    private final ObjectMapper objectMapper;
    private final QuizRepository quizRepository;
    private final CourseRepository courseRepository;
    private final DatabaseCleanUp databaseCleanUp;

    AuthoringAcceptanceTest(
            @Autowired MockMvc mockMvc,
            @Autowired JwtTokenProvider jwtTokenProvider,
            @Autowired ObjectMapper objectMapper,
            @Autowired QuizRepository quizRepository,
            @Autowired CourseRepository courseRepository,
            @Autowired DatabaseCleanUp databaseCleanUp) {
        this.mockMvc = mockMvc;
        this.jwtTokenProvider = jwtTokenProvider;
        this.objectMapper = objectMapper;
        this.quizRepository = quizRepository;
        this.courseRepository = courseRepository;
        this.databaseCleanUp = databaseCleanUp;
    }

    // 이 클래스의 두 테스트가 잡 큐 상태(QUEUED 잔존 여부)를 서로 오염시키지 않도록 매번 빈 테이블에서 시작한다.
    @BeforeEach
    void cleanSeedData() {
        databaseCleanUp.execute();
        // 승인(NEW draft materialize)이 QuizPersister의 기본 코스 해석 경로를 타므로, 매 테스트마다
        // 최소 코스 1개는 있어야 한다 — DatabaseCleanUp이 Flyway 시드 코스까지 지운다.
        courseRepository.save(Course.create("운영체제", "CS"));
    }

    /** 저작(#174) 경로는 ADMIN 전용이라(#174 C1) 인수 테스트 토큰도 ADMIN role로 발급한다. */
    private String bearerToken(long userId) {
        return "Bearer " + jwtTokenProvider.createAccessToken(userId, "ADMIN");
    }

    private JsonNode data(org.springframework.test.web.servlet.ResultActions result) throws Exception {
        String body = result.andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);
        return objectMapper.readTree(body).path("data");
    }

    @Test
    @DisplayName("generate 요청부터 승인까지 대시보드-브리지 전체 흐름이 이어진다")
    void 생성_잡_전체_흐름() throws Exception {
        long quizCountBefore = quizRepository.count();

        long jobId = requestGenerate();
        claimNextAndAssert(jobId);
        submitLogsAndResult(jobId);
        long draftId = assertJobSucceededAndReturnDraftId(jobId);
        assertDraftDetailHasOneRevisionAndFiveQuizzes(draftId);

        mockMvc.perform(post("/api/v1/authoring/drafts/{draftId}/approve", draftId)
                        .header(HttpHeaders.AUTHORIZATION, bearerToken(USER_ID)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.status").value("APPROVED"));
        assertThat(quizRepository.count()).isEqualTo(quizCountBefore + 5);
    }

    /** 1) 대시보드: 생성 잡 등록 */
    private long requestGenerate() throws Exception {
        JsonNode generateData = data(mockMvc.perform(post("/api/v1/authoring/drafts/generate")
                        .header(HttpHeaders.AUTHORIZATION, bearerToken(USER_ID))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"topic\":\"운영체제\"}"))
                .andExpect(status().isAccepted()));
        return generateData.path("jobId").asLong();
    }

    /** 2) 브리지: 잡을 폴링해서 집는다 */
    private void claimNextAndAssert(long jobId) throws Exception {
        JsonNode nextData = data(mockMvc.perform(get("/api/v1/authoring/bridge/jobs/next")
                        .header(HttpHeaders.AUTHORIZATION, bearerToken(USER_ID)))
                .andExpect(status().isOk()));
        assertThat(nextData.path("jobId").asLong()).isEqualTo(jobId);
        assertThat(nextData.path("prompt").asText()).contains("운영체제");
        assertThat(nextData.path("outputSchema").path("required").toString()).contains("quizzes");
    }

    /** 3) 브리지: 실행 로그 적재 → 4) 결과 제출(유효한 5문제 세트) */
    private void submitLogsAndResult(long jobId) throws Exception {
        mockMvc.perform(post("/api/v1/authoring/bridge/jobs/{jobId}/logs", jobId)
                        .header(HttpHeaders.AUTHORIZATION, bearerToken(USER_ID))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lines\":[\"시작\",\"생성 중\"]}"))
                .andExpect(status().isOk());

        String resultRequest = objectMapper.writeValueAsString(
                new BridgeResultRequestFixture("CLAUDE", GeneratedQuizJsonFixture.validSetJson()));
        JsonNode resultData = data(mockMvc.perform(post("/api/v1/authoring/bridge/jobs/{jobId}/result", jobId)
                        .header(HttpHeaders.AUTHORIZATION, bearerToken(USER_ID))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(resultRequest))
                .andExpect(status().isOk()));
        assertThat(resultData.path("status").asText()).isEqualTo("SUCCEEDED");
    }

    /** 5) 대시보드: 잡 상태 조회 — draftId가 붙어 있어야 한다 */
    private long assertJobSucceededAndReturnDraftId(long jobId) throws Exception {
        JsonNode jobStatusData = data(mockMvc.perform(get("/api/v1/authoring/jobs/{jobId}", jobId)
                        .header(HttpHeaders.AUTHORIZATION, bearerToken(USER_ID)))
                .andExpect(status().isOk()));
        assertThat(jobStatusData.path("status").asText()).isEqualTo("SUCCEEDED");
        long draftId = jobStatusData.path("draftId").asLong();
        assertThat(draftId).isPositive();
        return draftId;
    }

    /** 6) 대시보드: draft 상세 — rev1이 남았고 payload에 5문제가 들어 있다 */
    private void assertDraftDetailHasOneRevisionAndFiveQuizzes(long draftId) throws Exception {
        JsonNode draftDetailData = data(mockMvc.perform(get("/api/v1/authoring/drafts/{draftId}", draftId)
                        .header(HttpHeaders.AUTHORIZATION, bearerToken(USER_ID)))
                .andExpect(status().isOk()));
        assertThat(draftDetailData.path("revisions")).hasSize(1);
        assertThat(draftDetailData.path("payload").path("quizzes")).hasSize(5);
    }

    @Test
    @DisplayName("남의 잡은 next로 집을 수 없다 — assignee가 다르면 data:null")
    void 남의_잡은_next로_집을_수_없다() throws Exception {
        mockMvc.perform(post("/api/v1/authoring/drafts/generate")
                        .header(HttpHeaders.AUTHORIZATION, bearerToken(USER_ID))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"topic\":\"네트워크\"}"))
                .andExpect(status().isAccepted());

        JsonNode nextData = data(mockMvc.perform(get("/api/v1/authoring/bridge/jobs/next")
                        .header(HttpHeaders.AUTHORIZATION, bearerToken(OTHER_USER_ID)))
                .andExpect(status().isOk()));

        assertThat(nextData.isNull()).isTrue();
    }

    @Test
    @DisplayName("ADMIN이 아닌 유저는 저작 API에 403으로 막힌다 — 대시보드·브리지 경로 공통")
    void 관리자가_아니면_저작_API는_403() throws Exception {
        String nonAdminToken = "Bearer " + jwtTokenProvider.createAccessToken(USER_ID, "USER");

        mockMvc.perform(post("/api/v1/authoring/drafts/generate")
                        .header(HttpHeaders.AUTHORIZATION, nonAdminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"topic\":\"운영체제\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));

        mockMvc.perform(get("/api/v1/authoring/bridge/jobs/next").header(HttpHeaders.AUTHORIZATION, nonAdminToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));
    }

    @Test
    @DisplayName("Authorization 헤더가 없으면 저작 API도 401로 막힌다 — 403이 아니라 401이어야 한다")
    void 미인증이면_저작_API는_401() throws Exception {
        mockMvc.perform(get("/api/v1/authoring/drafts")).andExpect(status().isUnauthorized());
    }

    /** {@code BridgeResultRequest}는 record라 필드명이 그대로 JSON 키가 된다 — 테스트에서 별도 DTO import 없이 직렬화용으로만 쓴다. */
    private record BridgeResultRequestFixture(String cli, String resultJson) {}
}
