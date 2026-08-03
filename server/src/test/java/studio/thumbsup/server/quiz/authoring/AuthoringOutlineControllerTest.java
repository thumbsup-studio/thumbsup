package studio.thumbsup.server.quiz.authoring;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
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
import studio.thumbsup.server.quiz.authoring.dto.CreateOutlineRequest;
import studio.thumbsup.server.quiz.authoring.dto.CreateOutlineStepRequest;
import studio.thumbsup.server.quiz.authoring.dto.GenerateStepRequest;
import studio.thumbsup.server.quiz.authoring.dto.OutlineCreatedResponse;
import studio.thumbsup.server.quiz.authoring.dto.OutlineDetailResponse;
import studio.thumbsup.server.quiz.authoring.dto.OutlineListResponse;
import studio.thumbsup.server.quiz.authoring.dto.OutlineStepResponse;
import studio.thumbsup.server.quiz.authoring.dto.PublishResponse;
import studio.thumbsup.server.quiz.authoring.dto.ReorderStepRequest;
import studio.thumbsup.server.quiz.authoring.dto.StepCreatedResponse;
import studio.thumbsup.server.quiz.authoring.dto.UpdateOutlineRequest;
import studio.thumbsup.server.quiz.authoring.dto.UpdateOutlineStepRequest;
import studio.thumbsup.server.quiz.generation.QuizPreset;

@ExtendWith(MockitoExtension.class)
class AuthoringOutlineControllerTest {

    @Mock
    private AuthoringOutlineService outlineService;

    @Mock
    private AuthoringJobService jobService;

    @Mock
    private AuthoringPublishService publishService;

    private MockMvc mockMvc;
    private final ObjectMapper objectMapper = new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(
                        new AuthoringOutlineController(outlineService, publishService),
                        new AuthoringOutlineStepController(outlineService, jobService))
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

    @Test
    @DisplayName("뼈대 생성은 202와 outlineId·jobId를 반환한다")
    void createsOutline() throws Exception {
        given(outlineService.createOutline(7L, "네트워크", "CS", "1장")).willReturn(new OutlineCreatedResponse(1L, 2L));

        mockMvc.perform(post("/api/v1/authoring/outlines")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateOutlineRequest("네트워크", "CS", "1장"))))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.data.outlineId").value(1))
                .andExpect(jsonPath("$.data.jobId").value(2));
    }

    @Test
    @DisplayName("toc가 공백이면 400 INVALID_INPUT이다")
    void rejectsBlankToc() throws Exception {
        mockMvc.perform(post("/api/v1/authoring/outlines")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateOutlineRequest("네트워크", "CS", " "))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_INPUT"))
                .andExpect(jsonPath("$.data.fieldErrors[0].field").value("toc"));
    }

    @Test
    @DisplayName("목록·상세 조회는 서비스 DTO를 envelope로 감싼다")
    void readsListAndDetail() throws Exception {
        OutlineStepResponse step =
                new OutlineStepResponse(11L, 1, "네트워크", "기초를 설명한다", OutlineStepFillState.EMPTY, null, null);
        given(outlineService.listSummaries()).willReturn(new OutlineListResponse(List.of()));
        given(outlineService.getDetail(1L))
                .willReturn(new OutlineDetailResponse(1L, "네트워크", "CS", "DRAFT", "1장", List.of(step)));

        mockMvc.perform(get("/api/v1/authoring/outlines"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.outlines").isArray());
        mockMvc.perform(get("/api/v1/authoring/outlines/1"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.steps[0].fillState").value("EMPTY"));
    }

    @Nested
    @DisplayName("뼈대 편집 endpoint")
    class Editing {

        @Test
        @DisplayName("재생성·스텝 추가는 202다")
        void enqueuesJobs() throws Exception {
            given(outlineService.regenerate(7L, 1L)).willReturn(3L);
            given(outlineService.addStep(1L, "프로세스")).willReturn(new StepCreatedResponse(4L));
            given(jobService.enqueueStepGenerate(7L, 4L, QuizPreset.LIGHT_3)).willReturn(5L);

            mockMvc.perform(post("/api/v1/authoring/outlines/1/outline-jobs"))
                    .andExpect(status().isAccepted())
                    .andExpect(jsonPath("$.data.jobId").value(3));
            mockMvc.perform(post("/api/v1/authoring/outlines/1/steps")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(new CreateOutlineStepRequest("프로세스"))))
                    // 스텝 추가는 잡을 만들지 않고 즉시 저장한다 — 202가 아니라 201이다.
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.data.stepId").value(4));
            mockMvc.perform(post("/api/v1/authoring/outline-steps/4/generate")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(new GenerateStepRequest(QuizPreset.LIGHT_3))))
                    .andExpect(status().isAccepted())
                    .andExpect(jsonPath("$.data.jobId").value(5));
        }

        @Test
        @DisplayName("제목·스텝·순서 편집은 서비스에 위임한다")
        void delegatesEdits() throws Exception {
            mockMvc.perform(patch("/api/v1/authoring/outlines/1")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(new UpdateOutlineRequest("새 제목", "새 분류"))))
                    .andExpect(status().isOk());
            mockMvc.perform(patch("/api/v1/authoring/outline-steps/4")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(new UpdateOutlineStepRequest("새 주제"))))
                    .andExpect(status().isOk());
            mockMvc.perform(delete("/api/v1/authoring/outline-steps/4")).andExpect(status().isOk());
            mockMvc.perform(patch("/api/v1/authoring/outline-steps/4/order")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(new ReorderStepRequest("UP"))))
                    .andExpect(status().isOk());

            verify(outlineService).updateOutline(eq(1L), eq("새 제목"), eq("새 분류"));
            verify(outlineService).updateStep(eq(4L), eq("새 주제"));
            verify(outlineService).deleteStep(eq(4L));
            verify(outlineService).reorderStep(eq(4L), eq("UP"));
        }

        @Test
        @DisplayName("발행은 인증 사용자와 outlineId를 서비스에 위임한다")
        void publishesOutline() throws Exception {
            given(publishService.publish(7L, 1L)).willReturn(new PublishResponse(9L, 3));

            mockMvc.perform(post("/api/v1/authoring/outlines/1/publish"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.courseId").value(9))
                    .andExpect(jsonPath("$.data.stepCount").value(3));

            verify(publishService).publish(7L, 1L);
        }
    }
}
