package studio.thumbsup.server.quiz.authoring;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import java.time.OffsetDateTime;
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
import studio.thumbsup.server.common.exception.GlobalExceptionHandler;
import studio.thumbsup.server.quiz.authoring.dto.ApproveResponse;
import studio.thumbsup.server.quiz.authoring.dto.DraftDetailResponse;
import studio.thumbsup.server.quiz.authoring.dto.DraftListResponse;
import studio.thumbsup.server.quiz.authoring.dto.DraftSummaryResponse;
import studio.thumbsup.server.quiz.authoring.dto.GenerateRequest;
import studio.thumbsup.server.quiz.authoring.dto.ReviewRequest;

/** Controller 슬라이스 테스트 — standalone MockMvc로 요청/응답 계약만 검증한다 (피라미드 2층). */
@ExtendWith(MockitoExtension.class)
class AuthoringDraftControllerTest {

    @Mock
    private AuthoringJobService jobService;

    @Mock
    private AuthoringDraftService draftService;

    @Mock
    private AuthoringApprovalService approvalService;

    private MockMvc mockMvc;
    // standalone은 Boot 자동설정이 없어 java.time 직렬화를 명시해야 한다 — 운영 ObjectMapper와 별개 인스턴스.
    private final ObjectMapper objectMapper = new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(
                        new AuthoringDraftController(jobService, draftService, approvalService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .setMessageConverters(new MappingJackson2HttpMessageConverter(objectMapper))
                .setCustomArgumentResolvers(new AuthenticationPrincipalArgumentResolver())
                .build();
        SecurityContextHolder.getContext()
                .setAuthentication(new UsernamePasswordAuthenticationToken(7L, null, List.of()));
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Nested
    @DisplayName("생성 잡 등록")
    class Generate {

        @Test
        @DisplayName("성공하면 202와 jobId를 반환한다")
        void returns_202_with_job_id_on_success() throws Exception {
            given(jobService.enqueueGenerate(eq(7L), eq("운영체제"))).willReturn(100L);

            mockMvc.perform(post("/api/v1/authoring/drafts/generate")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(new GenerateRequest("운영체제"))))
                    .andExpect(status().isAccepted())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.jobId").value(100));
        }

        @Test
        @DisplayName("topic이 공백이면 400 INVALID_INPUT과 fieldErrors를 반환한다")
        void returns_400_when_topic_is_blank() throws Exception {
            mockMvc.perform(post("/api/v1/authoring/drafts/generate")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(new GenerateRequest("   "))))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("INVALID_INPUT"))
                    .andExpect(jsonPath("$.data.fieldErrors[0].field").value("topic"));
        }
    }

    @Nested
    @DisplayName("검수 잡 등록")
    class Review {

        @Test
        @DisplayName("성공하면 202와 jobId를 반환한다")
        void returns_202_with_job_id_on_success() throws Exception {
            given(jobService.enqueueReview(eq(7L), eq(1L), eq("선지가 모호함"))).willReturn(200L);

            mockMvc.perform(post("/api/v1/authoring/drafts/1/reviews")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(new ReviewRequest("선지가 모호함"))))
                    .andExpect(status().isAccepted())
                    .andExpect(jsonPath("$.data.jobId").value(200));
        }
    }

    @Nested
    @DisplayName("승인")
    class Approve {

        @Test
        @DisplayName("성공하면 200과 draftId·status를 반환한다")
        void returns_200_with_draft_id_and_status_on_success() throws Exception {
            given(approvalService.approveForResponse(eq(7L), eq(1L))).willReturn(new ApproveResponse(1L, "APPROVED"));

            mockMvc.perform(post("/api/v1/authoring/drafts/1/approve"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.draftId").value(1))
                    .andExpect(jsonPath("$.data.status").value("APPROVED"));
        }
    }

    @Nested
    @DisplayName("목록 조회")
    class ListDrafts {

        @Test
        @DisplayName("성공하면 200과 drafts 배열을 반환한다")
        void returns_200_with_drafts_array_on_success() throws Exception {
            DraftSummaryResponse summary =
                    new DraftSummaryResponse(1L, "NEW", "DRAFT", "운영체제", null, 1, OffsetDateTime.now());
            given(draftService.listSummaries(eq(QuizDraftStatus.DRAFT)))
                    .willReturn(new DraftListResponse(List.of(summary)));

            mockMvc.perform(get("/api/v1/authoring/drafts").param("status", "DRAFT"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.drafts[0].draftId").value(1))
                    .andExpect(jsonPath("$.data.drafts[0].origin").value("NEW"));
        }
    }

    @Nested
    @DisplayName("상세 조회")
    class Detail {

        @Test
        @DisplayName("성공하면 200과 draft 상세를 반환한다")
        void returns_200_with_draft_detail_on_success() throws Exception {
            JsonNode payload = objectMapper.readTree("{\"quizzes\":[]}");
            given(draftService.getDetail(eq(1L)))
                    .willReturn(new DraftDetailResponse(
                            1L,
                            "NEW",
                            "DRAFT",
                            "운영체제",
                            null,
                            1,
                            OffsetDateTime.now(),
                            payload,
                            List.of(),
                            7L,
                            null,
                            null));

            mockMvc.perform(get("/api/v1/authoring/drafts/1"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.draftId").value(1))
                    .andExpect(jsonPath("$.data.payload.quizzes").isArray());
        }
    }
}
