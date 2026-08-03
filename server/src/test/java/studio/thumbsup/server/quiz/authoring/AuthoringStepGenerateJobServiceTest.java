package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
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
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;
import studio.thumbsup.server.quiz.generation.GeneratedQuizValidator;
import studio.thumbsup.server.quiz.generation.QuizPreset;

@ExtendWith(MockitoExtension.class)
class AuthoringStepGenerateJobServiceTest {

    private static final Instant NOW = Instant.parse("2026-08-02T00:00:00Z");

    @Mock
    private GenerationJobRepository generationJobRepository;

    @Mock
    private QuizRepository quizRepository;

    @Mock
    private QuizStepRepository quizStepRepository;

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

    @Test
    @DisplayName("스텝 생성 잡은 프리셋과 뼈대 맥락을 담아 저장한다")
    void enqueuesStepGenerateJob() {
        AuthoringOutline outline = outline(1L);
        AuthoringOutlineStep step = step(10L, 2, "프로세스", "프로세스의 실행을 설명한다");
        OutlineStepContext context = new OutlineStepContext(
                "운영체제", 2, 3, "프로세스", "프로세스의 실행을 설명한다", "컴퓨터 구조", "스레드", List.of("프로세스 상태를 구분한다"));
        given(draftService.getOutlineStepOrThrow(10L)).willReturn(step);
        given(draftService.getOutlineForUpdate(1L)).willReturn(outline);
        given(draftService.outlineStepContext(10L)).willReturn(context);
        given(generationJobRepository.findByOutlineStepIdAndStatusIn(eq(10L), any()))
                .willReturn(List.of());
        given(generationJobRepository.save(any())).willAnswer(invocation -> {
            GenerationJob job = invocation.getArgument(0);
            ReflectionTestUtils.setField(job, "id", 101L);
            return job;
        });

        Long jobId = service.enqueueStepGenerate(7L, 10L, QuizPreset.LIGHT_3);

        assertThat(jobId).isEqualTo(101L);
        ArgumentCaptor<GenerationJob> captor = ArgumentCaptor.forClass(GenerationJob.class);
        verify(generationJobRepository).save(captor.capture());
        assertThat(captor.getValue().getKind()).isEqualTo(GenerationJobKind.GENERATE);
        assertThat(captor.getValue().getOutlineStepId()).isEqualTo(10L);
        assertThat(captor.getValue().getPreset()).isEqualTo(QuizPreset.LIGHT_3);
        assertThat(captor.getValue().getPrompt()).contains("컴퓨터 구조").contains("스레드");
    }

    @Nested
    @DisplayName("스텝 생성 가드는")
    class EnqueueGuards {

        @Test
        @DisplayName("이미 draft가 붙은 스텝에 생성 요청하면 409다")
        void rejectsGenerateOnFilledStep() {
            AuthoringOutlineStep step = step(10L, 1, "프로세스", null);
            step.attachDraft(99L);
            given(draftService.getOutlineStepOrThrow(10L)).willReturn(step);
            given(draftService.getOutlineForUpdate(1L)).willReturn(outline(1L));

            assertThatThrownBy(() -> service.enqueueStepGenerate(7L, 10L, QuizPreset.BASIC_5))
                    .isInstanceOf(BusinessException.class)
                    .extracting(exception -> ((BusinessException) exception).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_OUTLINE_STEP_FILLED);
            verify(generationJobRepository, never()).save(any());
        }

        @Test
        @DisplayName("활성 잡이 있는 스텝에 생성 요청하면 409다")
        void rejectsGenerateWhenJobActive() {
            AuthoringOutlineStep step = step(10L, 1, "프로세스", null);
            GenerationJob activeJob = GenerationJob.createStepGenerate(7L, 10L, "프로세스", QuizPreset.BASIC_5, "prompt");
            activeJob.markRunning(NOW.minusSeconds(30));
            given(draftService.getOutlineStepOrThrow(10L)).willReturn(step);
            given(draftService.getOutlineForUpdate(1L)).willReturn(outline(1L));
            given(generationJobRepository.findByOutlineStepIdAndStatusIn(eq(10L), any()))
                    .willReturn(List.of(activeJob));

            assertThatThrownBy(() -> service.enqueueStepGenerate(7L, 10L, QuizPreset.BASIC_5))
                    .isInstanceOf(BusinessException.class)
                    .extracting(exception -> ((BusinessException) exception).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_DRAFT_JOB_ACTIVE);
            verify(generationJobRepository, never()).save(any());
        }
    }

    @Nested
    @DisplayName("스텝 생성 결과는")
    class SubmitResult {

        @Test
        @DisplayName("OUTLINE_STEP draft를 만들고 검증 성공으로 종결한다")
        void createsOutlineStepDraftAndLinks() {
            GenerationJob job = GenerationJob.createStepGenerate(7L, 10L, "프로세스", QuizPreset.LIGHT_3, "prompt");
            ReflectionTestUtils.setField(job, "id", 201L);
            job.markRunning(NOW.minusSeconds(30));
            given(generationJobRepository.findById(201L)).willReturn(Optional.of(job));
            QuizDraft draft = QuizDraft.createForOutlineStep("프로세스", "{}", QuizPreset.LIGHT_3, 7L);
            given(draftService.createFromGenerate(eq(job), any(GeneratedQuizSet.class), eq(QuizPreset.LIGHT_3)))
                    .willReturn(draft);

            GenerationJob result =
                    service.submitResult(7L, 201L, BridgeCli.CLAUDE, GeneratedQuizJsonFixture.light3SetJson());

            assertThat(result.getStatus()).isEqualTo(GenerationJobStatus.SUCCEEDED);
            verify(draftService).createFromGenerate(eq(job), any(GeneratedQuizSet.class), eq(QuizPreset.LIGHT_3));
        }

        @Test
        @DisplayName("LIGHT_3 잡에 5문제가 오면 FAILED로 종결한다")
        void validatesWithJobPreset() {
            GenerationJob job = GenerationJob.createStepGenerate(7L, 10L, "프로세스", QuizPreset.LIGHT_3, "prompt");
            ReflectionTestUtils.setField(job, "id", 202L);
            job.markRunning(NOW.minusSeconds(30));
            given(generationJobRepository.findById(202L)).willReturn(Optional.of(job));

            GenerationJob result =
                    service.submitResult(7L, 202L, BridgeCli.CLAUDE, GeneratedQuizJsonFixture.validSetJson());

            assertThat(result.getStatus()).isEqualTo(GenerationJobStatus.FAILED);
            assertThat(result.getError()).contains("3개가 아닙니다");
            verify(draftService, never()).createFromGenerate(any(), any(), any());
        }
    }

    private static AuthoringOutline outline(Long id) {
        AuthoringOutline outline = AuthoringOutline.create("운영체제", "CS", "목차", 7L);
        ReflectionTestUtils.setField(outline, "id", id);
        return outline;
    }

    private static AuthoringOutlineStep step(Long id, int orderNo, String topic, String learningGoal) {
        AuthoringOutlineStep step = AuthoringOutlineStep.create(1L, orderNo, topic, learningGoal);
        ReflectionTestUtils.setField(step, "id", id);
        return step;
    }
}
