package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.authoring.dto.BridgeJobResponse;
import studio.thumbsup.server.quiz.generation.GeneratedQuizValidator;

@ExtendWith(MockitoExtension.class)
class AuthoringOutlineJobServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-14T00:00:00Z");

    @Mock
    private GenerationJobRepository generationJobRepository;

    @Mock
    private studio.thumbsup.server.quiz.QuizRepository quizRepository;

    @Mock
    private studio.thumbsup.server.quiz.QuizStepRepository quizStepRepository;

    @Mock
    private AuthoringDraftService draftService;

    private AuthoringJobService service;

    @BeforeEach
    void setUp() {
        ObjectMapper objectMapper = new ObjectMapper();
        service = new AuthoringJobService(
                generationJobRepository,
                quizRepository,
                quizStepRepository,
                draftService,
                new GeneratedQuizValidator(objectMapper),
                objectMapper,
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @Nested
    @DisplayName("뼈대 잡 생성은")
    class EnqueueOutline {

        @Test
        @DisplayName("뼈대 정보를 담은 OUTLINE 잡을 저장한다")
        void saves_outline_job_with_outline_prompt() {
            AuthoringOutline outline = AuthoringOutline.create("네트워크 기초", "네트워크", "1장 네트워크", 1L);
            ReflectionTestUtils.setField(outline, "id", 30L);
            given(draftService.getOutlineForUpdate(30L)).willReturn(outline);
            given(draftService.hasFilledOutlineSteps(30L)).willReturn(false);
            given(generationJobRepository.save(any())).willAnswer(invocation -> {
                GenerationJob job = invocation.getArgument(0);
                ReflectionTestUtils.setField(job, "id", 301L);
                return job;
            });

            Long jobId = service.enqueueOutline(1L, 30L);

            assertThat(jobId).isEqualTo(301L);
            ArgumentCaptor<GenerationJob> captor = ArgumentCaptor.forClass(GenerationJob.class);
            verify(generationJobRepository).save(captor.capture());
            assertThat(captor.getValue().getKind()).isEqualTo(GenerationJobKind.OUTLINE);
            assertThat(captor.getValue().getOutlineId()).isEqualTo(30L);
            assertThat(captor.getValue().getPrompt()).contains("네트워크 기초").contains("1장 네트워크");
        }

        @Test
        @DisplayName("이미 draft가 붙은 뼈대는 재생성할 수 없다")
        void rejects_outline_regeneration_when_step_is_filled() {
            AuthoringOutline outline = AuthoringOutline.create("네트워크 기초", "네트워크", "목차", 1L);
            given(draftService.getOutlineForUpdate(30L)).willReturn(outline);
            given(draftService.hasFilledOutlineSteps(30L)).willReturn(true);

            assertThatThrownBy(() -> service.enqueueOutline(1L, 30L))
                    .isInstanceOf(BusinessException.class)
                    .extracting(exception -> ((BusinessException) exception).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_OUTLINE_STEP_FILLED);
            verify(generationJobRepository, never()).save(any());
        }
    }

    @Nested
    @DisplayName("브리지 출력 스키마는")
    class BridgeSchema {

        @Test
        @DisplayName("OUTLINE 잡을 브리지에 넘길 때 OUTLINE 출력 스키마를 함께 준다")
        void returns_outline_output_schema_for_outline_job() {
            GenerationJob job = GenerationJob.createOutline(1L, 90L, "p");
            ReflectionTestUtils.setField(job, "id", 101L);
            given(generationJobRepository.pickNextQueued(1L)).willReturn(Optional.of(job));

            BridgeJobResponse response = service.claimNextForBridge(1L).orElseThrow();

            assertThat(response.kind()).isEqualTo("OUTLINE");
            assertThat(response.outputSchema().toString())
                    .contains("\"minItems\":3")
                    .contains("learningGoal");
        }
    }

    @Nested
    @DisplayName("OUTLINE 잡 결과 처리는")
    class OutlineResultHandling {

        @Test
        @DisplayName("스텝을 1부터 순서대로 저장한다")
        void saves_outline_steps_in_order() {
            outlineJob(15L);
            given(draftService.hasFilledOutlineSteps(90L)).willReturn(false);

            GenerationJob result =
                    service.submitResult(1L, 15L, BridgeCli.CLAUDE, outlineResultJson("프로세스", "스레드", "동기화"));

            assertThat(result.getStatus()).isEqualTo(GenerationJobStatus.SUCCEEDED);
            verify(draftService).replaceOutlineSteps(eq(90L), argThat(steps -> {
                assertThat(steps).extracting(AuthoringOutlineStep::getOrderNo).containsExactly(1, 2, 3);
                assertThat(steps).extracting(AuthoringOutlineStep::getTopic).containsExactly("프로세스", "스레드", "동기화");
                return true;
            }));
        }

        @Test
        @DisplayName("스텝이 3개 미만이면 잡을 FAILED로 마감한다")
        void fails_outline_job_when_too_few_steps() {
            outlineJob(16L);

            GenerationJob result = service.submitResult(1L, 16L, BridgeCli.CLAUDE, outlineResultJson("프로세스", "스레드"));

            assertThat(result.getStatus()).isEqualTo(GenerationJobStatus.FAILED);
            assertThat(result.getError()).contains("2개");
            verify(draftService, never()).replaceOutlineSteps(any(), any());
        }

        @Test
        @DisplayName("스텝이 20개를 넘으면 잡을 FAILED로 마감한다")
        void fails_outline_job_when_too_many_steps() {
            outlineJob(17L);
            String steps = java.util.stream.IntStream.rangeClosed(1, 21)
                    .mapToObj(index -> "{\"topic\":\"스텝" + index + "\",\"learningGoal\":\"목표\"}")
                    .collect(java.util.stream.Collectors.joining(","));

            GenerationJob result = service.submitResult(1L, 17L, BridgeCli.CLAUDE, "{\"steps\":[" + steps + "]}");

            assertThat(result.getStatus()).isEqualTo(GenerationJobStatus.FAILED);
            assertThat(result.getError()).contains("20개");
            verify(draftService, never()).replaceOutlineSteps(any(), any());
        }

        @Test
        @DisplayName("topic이 비어 있거나 중복이면 잡을 FAILED로 마감한다")
        void fails_outline_job_when_topic_is_blank_or_duplicated() {
            outlineJob(18L);
            GenerationJob blankResult =
                    service.submitResult(1L, 18L, BridgeCli.CLAUDE, outlineResultJson("프로세스", " ", "동기화"));
            assertThat(blankResult.getStatus()).isEqualTo(GenerationJobStatus.FAILED);

            outlineJob(19L);
            GenerationJob duplicateResult =
                    service.submitResult(1L, 19L, BridgeCli.CLAUDE, outlineResultJson("프로세스", "프로세스", "동기화"));
            assertThat(duplicateResult.getStatus()).isEqualTo(GenerationJobStatus.FAILED);
            verify(draftService, never()).replaceOutlineSteps(any(), any());
        }

        @Test
        @DisplayName("잡이 도는 동안 문제가 채워졌으면 기존 스텝을 보존하고 FAILED로 마감한다")
        void fails_outline_job_when_steps_are_already_filled() {
            outlineJob(20L);
            given(draftService.hasFilledOutlineSteps(90L)).willReturn(true);

            GenerationJob result =
                    service.submitResult(1L, 20L, BridgeCli.CLAUDE, outlineResultJson("프로세스", "스레드", "동기화"));

            assertThat(result.getStatus()).isEqualTo(GenerationJobStatus.FAILED);
            assertThat(result.getError()).contains("채워진");
            verify(draftService, never()).replaceOutlineSteps(any(), any());
        }
    }

    private GenerationJob outlineJob(Long jobId) {
        GenerationJob job = GenerationJob.createOutline(1L, 90L, "p");
        ReflectionTestUtils.setField(job, "id", jobId);
        job.markRunning(NOW.minus(Duration.ofSeconds(30)));
        given(generationJobRepository.findById(jobId)).willReturn(Optional.of(job));
        return job;
    }

    private String outlineResultJson(String... topics) {
        String steps = java.util.Arrays.stream(topics)
                .map(topic -> "{\"topic\":\"%s\",\"learningGoal\":\"목표\"}".formatted(topic))
                .collect(java.util.stream.Collectors.joining(","));
        return "{\"steps\":[%s]}".formatted(steps);
    }
}
