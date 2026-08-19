package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.willThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

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
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizFixture;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepBriefingRepository;
import studio.thumbsup.server.quiz.QuizType;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;
import studio.thumbsup.server.quiz.generation.GeneratedQuizValidator;
import studio.thumbsup.server.quiz.generation.QuizGenerationException;
import studio.thumbsup.server.quiz.generation.QuizPersister;
import studio.thumbsup.server.quiz.generation.QuizPreset;

@ExtendWith(MockitoExtension.class)
class AuthoringApprovalServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-14T00:00:00Z");

    @Mock
    private AuthoringDraftService draftService;

    @Mock
    private AuthoringJobService jobService;

    @Mock
    private GeneratedQuizValidator validator;

    @Mock
    private QuizRepository quizRepository;

    @Mock
    private QuizPersister quizPersister;

    @Mock
    private QuizStepBriefingRepository briefingRepository;

    private AuthoringApprovalService approvalService;

    @BeforeEach
    void setUp() {
        approvalService = new AuthoringApprovalService(
                draftService,
                jobService,
                validator,
                quizRepository,
                quizPersister,
                briefingRepository,
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @Nested
    @DisplayName("가드")
    class Guards {

        @Test
        @DisplayName("draft가 없으면 AUTHORING_DRAFT_NOT_FOUND가 그대로 전파된다")
        void propagates_draft_not_found() {
            given(draftService.getForUpdate(1L))
                    .willThrow(new BusinessException(AuthoringErrorType.AUTHORING_DRAFT_NOT_FOUND));

            assertThatThrownBy(() -> approvalService.approve(9L, 1L))
                    .isInstanceOf(BusinessException.class)
                    .extracting(ex -> ((BusinessException) ex).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_DRAFT_NOT_FOUND);
        }

        @Test
        @DisplayName("이미 승인된 draft면 AUTHORING_DRAFT_ALREADY_APPROVED")
        void rejects_already_approved_draft() {
            QuizDraft approved = QuizDraft.createNew("운영체제", "{}", 1L);
            approved.approve(3L, NOW);
            given(draftService.getForUpdate(1L)).willReturn(approved);

            assertThatThrownBy(() -> approvalService.approve(9L, 1L))
                    .isInstanceOf(BusinessException.class)
                    .extracting(ex -> ((BusinessException) ex).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_DRAFT_ALREADY_APPROVED);
        }

        @Test
        @DisplayName("draft에 활성 잡이 있으면 AUTHORING_DRAFT_JOB_ACTIVE")
        void rejects_when_draft_has_active_job() {
            QuizDraft draft = QuizDraft.createNew("운영체제", "{}", 1L);
            ReflectionTestUtils.setField(draft, "id", 1L);
            given(draftService.getForUpdate(1L)).willReturn(draft);
            willThrow(new BusinessException(AuthoringErrorType.AUTHORING_DRAFT_JOB_ACTIVE))
                    .given(jobService)
                    .guardDraftHasNoActiveJob(1L, NOW);

            assertThatThrownBy(() -> approvalService.approve(9L, 1L))
                    .isInstanceOf(BusinessException.class)
                    .extracting(ex -> ((BusinessException) ex).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_DRAFT_JOB_ACTIVE);
        }
    }

    @Nested
    @DisplayName("승인 처리")
    class Approve {

        @Test
        @DisplayName("NEW draft는 브리핑과 문제를 함께 발행하고 draft를 승인 상태로 만든다")
        void materializes_new_draft_via_persist() {
            QuizDraft draft = QuizDraft.createNew("운영체제", "{\"quizzes\":[]}", 1L);
            ReflectionTestUtils.setField(draft, "id", 1L);
            given(draftService.getForUpdate(1L)).willReturn(draft);
            GeneratedQuizSet set = currentStepSet();
            given(validator.parse("{\"quizzes\":[]}")).willReturn(set);
            given(validator.hasCurrentStepBriefing(set)).willReturn(true);
            QuizStep step = QuizStep.create(1, 1L, "운영체제", 3);
            ReflectionTestUtils.setField(step, "id", 2L);
            given(quizPersister.persistStep("운영체제", set)).willReturn(step);

            QuizDraft result = approvalService.approve(9L, 1L);

            verify(validator).validateStepContent(set, QuizPreset.BASIC_5);
            verify(quizPersister).persistStep("운영체제", set);
            verify(briefingRepository).save(any());
            assertThat(result.getStatus()).isEqualTo(QuizDraftStatus.APPROVED);
            assertThat(result.getApprovedBy()).isEqualTo(9L);
        }

        @Test
        @DisplayName("OUTLINE_STEP draft는 검증만 하고 라이브에 쓰지 않는다")
        void approves_outline_step_without_materializing() {
            QuizDraft draft = QuizDraft.createForOutlineStep("운영체제", "{}", QuizPreset.LIGHT_3, 1L);
            ReflectionTestUtils.setField(draft, "id", 3L);
            given(draftService.getForUpdate(3L)).willReturn(draft);
            GeneratedQuizSet set = currentStepSet();
            given(validator.parse("{}")).willReturn(set);
            given(validator.hasCurrentStepBriefing(set)).willReturn(true);

            QuizDraft result = approvalService.approve(9L, 3L);

            verify(validator).validateStepContent(set, QuizPreset.LIGHT_3);
            verify(quizPersister, never()).persist("운영체제", set);
            assertThat(result.getStatus()).isEqualTo(QuizDraftStatus.APPROVED);
            assertThat(result.getApprovedBy()).isEqualTo(9L);
        }

        @Test
        @DisplayName("OUTLINE_STEP draft의 검증에 실패하면 승인되지 않는다")
        void keeps_outline_step_draft_when_validation_fails() {
            QuizDraft draft = QuizDraft.createForOutlineStep("운영체제", "{}", QuizPreset.BASIC_5, 1L);
            ReflectionTestUtils.setField(draft, "id", 4L);
            given(draftService.getForUpdate(4L)).willReturn(draft);
            GeneratedQuizSet set = currentStepSet();
            given(validator.parse("{}")).willReturn(set);
            given(validator.hasCurrentStepBriefing(set)).willReturn(true);
            willThrow(new QuizGenerationException("힌트가 정답을 노출합니다"))
                    .given(validator)
                    .validateStepContent(set, QuizPreset.BASIC_5);

            assertThatThrownBy(() -> approvalService.approve(9L, 4L))
                    .isInstanceOf(BusinessException.class)
                    .extracting(exception -> ((BusinessException) exception).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_DRAFT_REVIEW_REQUIRED);
            assertThat(draft.getStatus()).isEqualTo(QuizDraftStatus.DRAFT);
            verify(quizPersister, never()).persist("운영체제", set);
            verify(quizPersister, never()).persistStep("운영체제", set);
        }

        @Test
        @DisplayName("브리핑이 없는 구형 NEW draft는 새로 생성하라고 차단한다")
        void rejects_legacy_draft_without_briefing_before_persisting() {
            QuizDraft draft = QuizDraft.createNew("운영체제", "{\"quizzes\":[]}", 1L);
            ReflectionTestUtils.setField(draft, "id", 1L);
            given(draftService.getForUpdate(1L)).willReturn(draft);
            GeneratedQuizSet set = new GeneratedQuizSet(List.of());
            given(validator.parse("{\"quizzes\":[]}")).willReturn(set);
            assertThatThrownBy(() -> approvalService.approve(9L, 1L))
                    .isInstanceOf(BusinessException.class)
                    .extracting(exception -> ((BusinessException) exception).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_LEGACY_DRAFT_REGENERATION_REQUIRED);

            verify(quizPersister, never()).persist("운영체제", set);
            verify(quizPersister, never()).persistStep("운영체제", set);
            assertThat(draft.getStatus()).isEqualTo(QuizDraftStatus.DRAFT);
        }

        @Test
        @DisplayName("브리핑이 없는 구형 OUTLINE_STEP draft는 새로 생성하라고 차단한다")
        void rejects_legacy_outline_step_draft_without_briefing() {
            QuizDraft draft = QuizDraft.createForOutlineStep("운영체제", "{}", QuizPreset.BASIC_5, 1L);
            ReflectionTestUtils.setField(draft, "id", 1L);
            given(draftService.getForUpdate(1L)).willReturn(draft);
            GeneratedQuizSet set = new GeneratedQuizSet(List.of());
            given(validator.parse("{}")).willReturn(set);

            assertThatThrownBy(() -> approvalService.approve(9L, 1L))
                    .isInstanceOf(BusinessException.class)
                    .extracting(exception -> ((BusinessException) exception).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_LEGACY_DRAFT_REGENERATION_REQUIRED);
            verify(quizPersister, never()).persistStep(any(), any());
            assertThat(draft.getStatus()).isEqualTo(QuizDraftStatus.DRAFT);
        }

        @Test
        @DisplayName("IMPROVE draft는 원본 quiz를 in-place로 갱신한다")
        void materializes_improve_draft_in_place() {
            QuizDraft draft = QuizDraft.createImprove("운영체제", 5L, "{\"quizzes\":[]}", 1L);
            ReflectionTestUtils.setField(draft, "id", 2L);
            given(draftService.getForUpdate(2L)).willReturn(draft);

            GeneratedQuizSet.GeneratedQuiz generatedQuiz = new GeneratedQuizSet.GeneratedQuiz(
                    QuizType.MULTIPLE_CHOICE,
                    QuizDifficulty.MEDIUM,
                    "개선된 질문",
                    "개선된 판단 단서를 떠올려 보세요.",
                    null,
                    "요약",
                    null,
                    "오답 해설",
                    null,
                    List.of(),
                    null,
                    List.of(),
                    List.of(),
                    List.of());
            GeneratedQuizSet set = new GeneratedQuizSet(List.of(generatedQuiz));
            given(validator.parse("{\"quizzes\":[]}")).willReturn(set);

            Quiz sourceQuiz = QuizFixture.multipleChoiceQuiz();
            ReflectionTestUtils.setField(sourceQuiz, "id", 5L);
            given(quizRepository.findById(5L)).willReturn(Optional.of(sourceQuiz));

            approvalService.approve(9L, 2L);

            assertThat(sourceQuiz.getQuestionText()).isEqualTo("개선된 질문");
            assertThat(sourceQuiz.getHint()).isEqualTo("개선된 판단 단서를 떠올려 보세요.");
            verify(validator).validateSingleHint(generatedQuiz, QuizType.MULTIPLE_CHOICE, QuizDifficulty.MEDIUM);
            verify(quizPersister).populate(sourceQuiz, generatedQuiz);
        }
    }

    private static GeneratedQuizSet currentStepSet() {
        return new GeneratedQuizSet(
                GeneratedQuizSet.STEP_BRIEFING_SCHEMA_VERSION,
                new GeneratedQuizSet.GeneratedBriefing(
                        "요약",
                        List.of(
                                new GeneratedQuizSet.GeneratedBriefingBlock(
                                        studio.thumbsup.server.quiz.QuizStepBriefingBlockType.CONCEPT, "핵심", "내용"),
                                new GeneratedQuizSet.GeneratedBriefingBlock(
                                        studio.thumbsup.server.quiz.QuizStepBriefingBlockType.CAUTION, "주의", "내용"))),
                List.of());
    }
}
