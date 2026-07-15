package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.request;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.HttpHeaders;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.DatabaseCleanUp;
import studio.thumbsup.server.common.security.JwtTokenProvider;

/**
 * 잡 로그 SSE 스트림(#174 T9) 인수 테스트 — 실제 MockMvc 요청을 태워 응답 본문의 SSE 와이어 포맷을
 * 검증한다. 순수 유닛 테스트로는 {@code SseEmitter}가 실제로 응답 본문을 어떻게 조립하는지 볼 수 없다.
 *
 * <p>{@code asyncDispatch}는 쓰지 않는다 — {@code subscribe()}의 모든 쓰기(리플레이·상태 이벤트)가
 * 컨트롤러 스레드 안에서 동기적으로 끝나므로, {@code request().asyncStarted()}로 async 처리가
 * 시작됐음을 확인한 직후 {@code MockHttpServletResponse}에 이미 쌓인 본문을 바로 읽으면 충분하다.
 * RUNNING 잡 케이스는 emitter가 의도적으로 열린 채 남기 때문에 {@code asyncDispatch}를 걸면
 * (아무도 complete를 호출하지 않아) emitter 타임아웃(30분)까지 블로킹된다 — 실제로 겪은 함정이라 기록.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@ActiveProfiles("test")
class JobLogStreamTest {

    private static final long USER_ID = 1L;

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final MockMvc mockMvc;
    private final JwtTokenProvider jwtTokenProvider;
    private final GenerationJobRepository generationJobRepository;
    private final JobLogRepository jobLogRepository;
    private final DatabaseCleanUp databaseCleanUp;

    JobLogStreamTest(
            @Autowired MockMvc mockMvc,
            @Autowired JwtTokenProvider jwtTokenProvider,
            @Autowired GenerationJobRepository generationJobRepository,
            @Autowired JobLogRepository jobLogRepository,
            @Autowired DatabaseCleanUp databaseCleanUp) {
        this.mockMvc = mockMvc;
        this.jwtTokenProvider = jwtTokenProvider;
        this.generationJobRepository = generationJobRepository;
        this.jobLogRepository = jobLogRepository;
        this.databaseCleanUp = databaseCleanUp;
    }

    @BeforeEach
    void cleanSeedData() {
        databaseCleanUp.execute();
    }

    /** 저작(#174) 경로는 ADMIN 전용이라(#174 C1) 토큰도 ADMIN role로 발급한다. */
    private String bearerToken() {
        return "Bearer " + jwtTokenProvider.createAccessToken(USER_ID, "ADMIN");
    }

    private String bodyOf(MvcResult started) throws Exception {
        return started.getResponse().getContentAsString(StandardCharsets.UTF_8);
    }

    @Test
    @DisplayName("RUNNING 잡을 fromSeq 이후로 구독하면 그 이후 로그만 리플레이한다")
    void replays_logs_after_from_seq() throws Exception {
        GenerationJob job = generationJobRepository.save(GenerationJob.createGenerate(USER_ID, "운영체제", "prompt"));
        job.markRunning(Instant.now());
        generationJobRepository.save(job);
        jobLogRepository.save(JobLog.create(job.getId(), 1, "시작"));
        jobLogRepository.save(JobLog.create(job.getId(), 2, "진행 중"));
        jobLogRepository.save(JobLog.create(job.getId(), 3, "거의 완료"));

        MvcResult started = mockMvc.perform(get("/api/v1/authoring/jobs/{jobId}/stream", job.getId())
                        .header(HttpHeaders.AUTHORIZATION, bearerToken())
                        .param("fromSeq", "1"))
                .andExpect(request().asyncStarted())
                .andReturn();

        String body = bodyOf(started);

        assertThat(body).contains("event:log").contains("\"seq\":2").contains("진행 중");
        assertThat(body).contains("\"seq\":3").contains("거의 완료");
        assertThat(body).doesNotContain("\"seq\":1");
    }

    @Test
    @DisplayName("이미 종결된 잡을 구독하면 상태 이벤트를 보내고 즉시 스트림을 종료한다")
    void terminal_job_sends_status_event_and_completes() throws Exception {
        GenerationJob job = generationJobRepository.save(GenerationJob.createGenerate(USER_ID, "네트워크", "prompt"));
        job.markRunning(Instant.now());
        job.succeed(BridgeCli.CLAUDE, Instant.now());
        generationJobRepository.save(job);

        MvcResult started = mockMvc.perform(get("/api/v1/authoring/jobs/{jobId}/stream", job.getId())
                        .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                .andExpect(request().asyncStarted())
                .andReturn();

        String body = bodyOf(started);

        assertThat(body).contains("event:status").contains("SUCCEEDED");
    }
}
