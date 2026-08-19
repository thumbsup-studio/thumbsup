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
import java.time.Duration;
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
import studio.thumbsup.server.common.exception.CommonErrorType;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizFixture;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.generation.GeneratedQuizJsonFixture;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;
import studio.thumbsup.server.quiz.generation.GeneratedQuizValidator;
import studio.thumbsup.server.quiz.generation.QuizPreset;

@ExtendWith(MockitoExtension.class)
class AuthoringJobServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-14T00:00:00Z");

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
        Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);
        service = new AuthoringJobService(
                generationJobRepository,
                quizRepository,
                quizStepRepository,
                draftService,
                new GeneratedQuizValidator(objectMapper),
                objectMapper,
                clock);
    }

    @Nested
    @DisplayName("enqueueGenerate")
    class EnqueueGenerate {

        @Test
        @DisplayName("GENERATE 잡을 저장하고 프롬프트에 topic을 포함한다")
        void saves_generate_job_with_topic_in_prompt() {
            given(generationJobRepository.save(any())).willAnswer(invocation -> {
                GenerationJob job = invocation.getArgument(0);
                ReflectionTestUtils.setField(job, "id", 100L);
                return job;
            });

            Long jobId = service.enqueueGenerate(1L, "운영체제");

            assertThat(jobId).isEqualTo(100L);
            ArgumentCaptor<GenerationJob> captor = ArgumentCaptor.forClass(GenerationJob.class);
            verify(generationJobRepository).save(captor.capture());
            assertThat(captor.getValue().getKind()).isEqualTo(GenerationJobKind.GENERATE);
            assertThat(captor.getValue().getPrompt()).contains("운영체제");
        }
    }

    @Nested
    @DisplayName("enqueueImprove")
    class EnqueueImprove {

        @Test
        @DisplayName("이미 열린 개선 draft가 있으면 AUTHORING_IMPROVE_DRAFT_EXISTS")
        void rejects_duplicate_improve_draft() {
            Quiz sourceQuiz = QuizFixture.oxQuiz();
            ReflectionTestUtils.setField(sourceQuiz, "id", 7L);
            given(quizRepository.findByIdForUpdate(7L)).willReturn(Optional.of(sourceQuiz));
            given(draftService.hasOpenImproveDraft(7L)).willReturn(true);

            assertThatThrownBy(() -> service.enqueueImprove(1L, 7L, "개선해줘"))
                    .isInstanceOf(BusinessException.class)
                    .extracting(ex -> ((BusinessException) ex).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_IMPROVE_DRAFT_EXISTS);
            verify(generationJobRepository, never()).save(any());
        }
    }

    @Nested
    @DisplayName("enqueueReview")
    class EnqueueReview {

        @Test
        @DisplayName("이미 승인된 draft면 AUTHORING_DRAFT_ALREADY_APPROVED")
        void rejects_when_draft_already_approved() {
            QuizDraft approved = QuizDraft.createNew("운영체제", "{}", 1L);
            approved.approve(9L, NOW);
            given(draftService.getForUpdate(5L)).willReturn(approved);

            assertThatThrownBy(() -> service.enqueueReview(1L, 5L, "피드백"))
                    .isInstanceOf(BusinessException.class)
                    .extracting(ex -> ((BusinessException) ex).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_DRAFT_ALREADY_APPROVED);
            verify(generationJobRepository, never()).save(any());
        }

        @Test
        @DisplayName("draft에 활성 잡이 있으면 AUTHORING_DRAFT_JOB_ACTIVE")
        void rejects_when_draft_has_active_job() {
            QuizDraft draft = QuizDraft.createNew("운영체제", "{}", 1L);
            ReflectionTestUtils.setField(draft, "id", 5L);
            given(draftService.getForUpdate(5L)).willReturn(draft);
            GenerationJob activeJob = GenerationJob.createGenerate(1L, "운영체제", "p");
            activeJob.markRunning(NOW.minus(Duration.ofMinutes(1))); // 아직 만료 아님
            given(generationJobRepository.findByDraftIdAndStatusIn(
                            eq(5L), eq(List.of(GenerationJobStatus.QUEUED, GenerationJobStatus.RUNNING))))
                    .willReturn(List.of(activeJob));

            assertThatThrownBy(() -> service.enqueueReview(1L, 5L, "피드백"))
                    .isInstanceOf(BusinessException.class)
                    .extracting(ex -> ((BusinessException) ex).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_DRAFT_JOB_ACTIVE);
            verify(generationJobRepository, never()).save(any());
        }

        @Test
        @DisplayName("RUNNING 10분 초과 잡은 만료 처리 후 성공한다")
        void succeeds_after_expiring_stale_running_job() {
            QuizDraft draft = QuizDraft.createNew("운영체제", "{}", 1L);
            ReflectionTestUtils.setField(draft, "id", 5L);
            given(draftService.getForUpdate(5L)).willReturn(draft);
            GenerationJob staleJob = GenerationJob.createGenerate(1L, "운영체제", "p");
            staleJob.markRunning(NOW.minus(Duration.ofMinutes(11))); // 10분 초과
            given(generationJobRepository.findByDraftIdAndStatusIn(
                            eq(5L), eq(List.of(GenerationJobStatus.QUEUED, GenerationJobStatus.RUNNING))))
                    .willReturn(List.of(staleJob));
            given(generationJobRepository.save(any())).willAnswer(invocation -> {
                GenerationJob job = invocation.getArgument(0);
                ReflectionTestUtils.setField(job, "id", 200L);
                return job;
            });

            Long jobId = service.enqueueReview(1L, 5L, "피드백");

            assertThat(jobId).isEqualTo(200L);
            assertThat(staleJob.getStatus()).isEqualTo(GenerationJobStatus.FAILED);
            assertThat(staleJob.getError()).isEqualTo("시간 초과로 만료되었습니다");
        }
    }

    @Nested
    @DisplayName("claimNext")
    class ClaimNext {

        @Test
        @DisplayName("QUEUED 잡을 집어 RUNNING으로 바꾼다")
        void picks_and_marks_running() {
            GenerationJob job = GenerationJob.createGenerate(1L, "운영체제", "p");
            given(generationJobRepository.pickNextQueued(1L)).willReturn(Optional.of(job));

            Optional<GenerationJob> claimed = service.claimNext(1L);

            assertThat(claimed).isPresent();
            assertThat(claimed.get().getStatus()).isEqualTo(GenerationJobStatus.RUNNING);
            assertThat(claimed.get().getStartedAt()).isEqualTo(NOW);
        }

        @Test
        @DisplayName("집을 잡이 없으면 empty를 반환한다")
        void returns_empty_when_nothing_to_claim() {
            given(generationJobRepository.pickNextQueued(1L)).willReturn(Optional.empty());

            assertThat(service.claimNext(1L)).isEmpty();
        }
    }

    @Nested
    @DisplayName("submitResult")
    class SubmitResult {

        @Test
        @DisplayName("남의 잡이면 FORBIDDEN")
        void rejects_when_not_owner() {
            GenerationJob job = GenerationJob.createGenerate(1L, "운영체제", "p");
            ReflectionTestUtils.setField(job, "id", 10L);
            given(generationJobRepository.findById(10L)).willReturn(Optional.of(job));

            assertThatThrownBy(() -> service.submitResult(2L, 10L, BridgeCli.CLAUDE, "{}"))
                    .isInstanceOf(BusinessException.class)
                    .extracting(ex -> ((BusinessException) ex).getErrorType())
                    .isEqualTo(CommonErrorType.FORBIDDEN);
        }

        @Test
        @DisplayName("GENERATE 성공 경로 — 브리핑과 문제를 검증하고 draft를 만든다")
        void succeeds_for_generate_job() {
            GenerationJob job = GenerationJob.createGenerate(1L, "운영체제", "p");
            ReflectionTestUtils.setField(job, "id", 11L);
            job.markRunning(NOW.minus(Duration.ofSeconds(30)));
            given(generationJobRepository.findById(11L)).willReturn(Optional.of(job));
            QuizDraft createdDraft = QuizDraft.createNew("운영체제", "{}", 1L);
            given(draftService.createFromGenerate(eq(job), any(GeneratedQuizSet.class)))
                    .willReturn(createdDraft);

            GenerationJob result = service.submitResult(
                    1L, 11L, BridgeCli.CLAUDE, stepContentJson(GeneratedQuizJsonFixture.validSetJson()));

            assertThat(result.getStatus()).isEqualTo(GenerationJobStatus.SUCCEEDED);
            assertThat(result.getCli()).isEqualTo(BridgeCli.CLAUDE);
            verify(draftService).createFromGenerate(eq(job), any(GeneratedQuizSet.class));
        }

        @Test
        @DisplayName("OUTLINE_STEP draft의 REVIEW 결과는 프리셋 슬롯 수로 검증한다")
        void validates_outline_step_review_as_set() {
            GenerationJob job = GenerationJob.createReview(1L, 51L, "피드백", "p");
            ReflectionTestUtils.setField(job, "id", 14L);
            job.markRunning(NOW.minus(Duration.ofSeconds(30)));
            given(generationJobRepository.findById(14L)).willReturn(Optional.of(job));

            QuizDraft outlineDraft = QuizDraft.createForOutlineStep("운영체제", "{}", QuizPreset.LIGHT_3, 1L);
            given(draftService.getOrThrow(51L)).willReturn(outlineDraft);
            given(draftService.applyReview(eq(job), any(ReviewResult.class))).willReturn(outlineDraft);

            String light3ReviewJson = stepContentJson(GeneratedQuizJsonFixture.light3SetJson())
                    .replace("{\"schemaVersion\":2,", "{\"reviewSummary\":\"수정함\",\"schemaVersion\":2,");

            GenerationJob result = service.submitResult(1L, 14L, BridgeCli.CODEX, light3ReviewJson);

            assertThat(result.getStatus()).isEqualTo(GenerationJobStatus.SUCCEEDED);
            verify(draftService).applyReview(eq(job), any(ReviewResult.class));
        }

        @Test
        @DisplayName("OUTLINE_STEP draft 검수 프롬프트에는 같은 뼈대의 형제 스텝이 포함된다")
        void includes_outline_sibling_topics_in_review_prompt() {
            GenerationJob job = GenerationJob.createReview(1L, 52L, "피드백", "p");
            QuizDraft draft = QuizDraft.createForOutlineStep("CPU 스케줄링", "{}", QuizPreset.BASIC_5, 1L);
            ReflectionTestUtils.setField(draft, "id", 52L);
            given(draftService.getForUpdate(52L)).willReturn(draft);
            given(generationJobRepository.findByDraftIdAndStatusIn(
                            eq(52L), eq(List.of(GenerationJobStatus.QUEUED, GenerationJobStatus.RUNNING))))
                    .willReturn(List.of());
            given(draftService.outlineSiblingTopics(52L)).willReturn(List.of("프로세스와 스레드", "프로세스 동기화"));
            given(generationJobRepository.save(any())).willAnswer(invocation -> {
                GenerationJob saved = invocation.getArgument(0);
                ReflectionTestUtils.setField(saved, "id", 202L);
                return saved;
            });

            Long jobId = service.enqueueReview(1L, 52L, "문제를 더 명확하게");

            assertThat(jobId).isEqualTo(202L);
            ArgumentCaptor<GenerationJob> captor = ArgumentCaptor.forClass(GenerationJob.class);
            verify(generationJobRepository).save(captor.capture());
            assertThat(captor.getValue().getPrompt()).contains("프로세스와 스레드").contains("프로세스 동기화");
        }

        @Test
        @DisplayName("검증에 실패하면 잡을 FAILED로 만들고 예외를 다시 던지지 않는다")
        void fails_job_on_validation_error_without_rethrowing() {
            GenerationJob job = GenerationJob.createGenerate(1L, "운영체제", "p");
            ReflectionTestUtils.setField(job, "id", 12L);
            job.markRunning(NOW.minus(Duration.ofSeconds(30)));
            given(generationJobRepository.findById(12L)).willReturn(Optional.of(job));

            GenerationJob result = service.submitResult(1L, 12L, BridgeCli.CLAUDE, "{\"quizzes\": []}");

            assertThat(result.getStatus()).isEqualTo(GenerationJobStatus.FAILED);
            assertThat(result.getError()).contains("5개가 아닙니다");
            verify(draftService, never()).createFromGenerate(any(), any());
        }

        @Test
        @DisplayName("REVIEW/IMPROVE draft는 원본 문제의 type·difficulty로 단건 검증한다")
        void succeeds_for_review_job_on_improve_draft() {
            GenerationJob job = GenerationJob.createReview(1L, 50L, "피드백", "p");
            ReflectionTestUtils.setField(job, "id", 13L);
            job.markRunning(NOW.minus(Duration.ofSeconds(30)));
            given(generationJobRepository.findById(13L)).willReturn(Optional.of(job));

            QuizDraft improveDraft = QuizDraft.createImprove("운영체제", 7L, "{}", 1L);
            given(draftService.getOrThrow(50L)).willReturn(improveDraft);
            given(draftService.applyReview(eq(job), any(ReviewResult.class))).willReturn(improveDraft);

            Quiz sourceQuiz = QuizFixture.oxQuiz(); // type=OX, difficulty=EASY
            ReflectionTestUtils.setField(sourceQuiz, "id", 7L);
            given(quizRepository.findById(7L)).willReturn(Optional.of(sourceQuiz));

            String resultJson =
                    "{\"reviewSummary\": \"수정함\", \"quizzes\": [%s]}".formatted(GeneratedQuizJsonFixture.oxQuizJson());

            GenerationJob result = service.submitResult(1L, 13L, BridgeCli.CODEX, resultJson);

            assertThat(result.getStatus()).isEqualTo(GenerationJobStatus.SUCCEEDED);
            verify(draftService).applyReview(eq(job), any(ReviewResult.class));
        }
    }

    @Nested
    @DisplayName("failJob")
    class FailJob {

        @Test
        @DisplayName("소유자가 아니면 FORBIDDEN")
        void rejects_when_not_owner() {
            GenerationJob job = GenerationJob.createGenerate(1L, "운영체제", "p");
            ReflectionTestUtils.setField(job, "id", 60L);
            given(generationJobRepository.findById(60L)).willReturn(Optional.of(job));

            assertThatThrownBy(() -> service.failJob(2L, 60L, "브리지 오류"))
                    .isInstanceOf(BusinessException.class)
                    .extracting(ex -> ((BusinessException) ex).getErrorType())
                    .isEqualTo(CommonErrorType.FORBIDDEN);
        }

        @Test
        @DisplayName("소유자면 잡을 FAILED로 기록한다")
        void marks_job_failed() {
            GenerationJob job = GenerationJob.createGenerate(1L, "운영체제", "p");
            ReflectionTestUtils.setField(job, "id", 61L);
            job.markRunning(NOW.minus(Duration.ofSeconds(10)));
            given(generationJobRepository.findById(61L)).willReturn(Optional.of(job));

            GenerationJob result = service.failJob(1L, 61L, "브리지 오류");

            assertThat(result.getStatus()).isEqualTo(GenerationJobStatus.FAILED);
            assertThat(result.getError()).isEqualTo("브리지 오류");
        }
    }

    @Nested
    @DisplayName("getJobWithExpiry")
    class GetJobWithExpiry {

        @Test
        @DisplayName("QUEUED 30분 초과 잡은 조회 시점에 만료 처리한다")
        void expires_stale_queued_job_on_read() {
            GenerationJob job = GenerationJob.createGenerate(1L, "운영체제", "p");
            ReflectionTestUtils.setField(job, "id", 70L);
            ReflectionTestUtils.setField(job, "createdAt", NOW.minus(Duration.ofMinutes(31)));
            given(generationJobRepository.findById(70L)).willReturn(Optional.of(job));

            GenerationJob result = service.getJobWithExpiry(70L);

            assertThat(result.getStatus()).isEqualTo(GenerationJobStatus.FAILED);
            assertThat(result.getError()).isEqualTo("시간 초과로 만료되었습니다");
        }
    }

    private static String stepContentJson(String quizJson) {
        return quizJson.replace(
                "{\"quizzes\":",
                "{\"schemaVersion\":2,\"briefing\":{\"summary\":\"요약\",\"blocks\":[{\"type\":\"CONCEPT\",\"heading\":\"핵심\",\"content\":\"개념\"},{\"type\":\"EXAMPLE\",\"heading\":\"예시\",\"content\":\"예시\"}]},\"quizzes\":");
    }
}
