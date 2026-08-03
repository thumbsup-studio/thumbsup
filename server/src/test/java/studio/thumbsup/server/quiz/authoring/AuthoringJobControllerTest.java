package studio.thumbsup.server.quiz.authoring;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import java.time.OffsetDateTime;
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
import studio.thumbsup.server.common.exception.GlobalExceptionHandler;
import studio.thumbsup.server.quiz.authoring.dto.JobStatusResponse;

/** Controller 슬라이스 테스트 — standalone MockMvc로 요청/응답 계약만 검증한다 (피라미드 2층). */
@ExtendWith(MockitoExtension.class)
class AuthoringJobControllerTest {

    @Mock
    private AuthoringJobService jobService;

    @Mock
    private JobLogStreamService jobLogStreamService;

    private MockMvc mockMvc;
    // standalone은 Boot 자동설정이 없어 java.time 직렬화를 명시해야 한다 — 운영 ObjectMapper와 별개 인스턴스.
    private final ObjectMapper objectMapper = new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(new AuthoringJobController(jobService, jobLogStreamService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .setMessageConverters(new MappingJackson2HttpMessageConverter(objectMapper))
                .build();
    }

    @Nested
    @DisplayName("잡 상태 조회")
    class GetJob {

        @Test
        @DisplayName("성공하면 200과 잡 상태를 반환한다")
        void returns_200_with_job_status_on_success() throws Exception {
            JobStatusResponse response = new JobStatusResponse(
                    1L,
                    "GENERATE",
                    "SUCCEEDED",
                    10L,
                    null,
                    OffsetDateTime.now(),
                    OffsetDateTime.now(),
                    OffsetDateTime.now(),
                    null,
                    null);
            given(jobService.getJobStatus(eq(1L))).willReturn(response);

            mockMvc.perform(get("/api/v1/authoring/jobs/1"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.jobId").value(1))
                    .andExpect(jsonPath("$.data.status").value("SUCCEEDED"))
                    .andExpect(jsonPath("$.data.draftId").value(10));
        }

        @Test
        @DisplayName("OUTLINE 잡 상태는 outlineId·outlineStepId를 포함한다")
        void returns_outline_references() throws Exception {
            JobStatusResponse response = new JobStatusResponse(
                    2L,
                    "OUTLINE",
                    "SUCCEEDED",
                    null,
                    null,
                    OffsetDateTime.now(),
                    null,
                    OffsetDateTime.now(),
                    90L,
                    null);
            given(jobService.getJobStatus(eq(2L))).willReturn(response);

            mockMvc.perform(get("/api/v1/authoring/jobs/2"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.kind").value("OUTLINE"))
                    .andExpect(jsonPath("$.data.outlineId").value(90));
        }
    }
}
