package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
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
import studio.thumbsup.server.quiz.QuizType;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;
import studio.thumbsup.server.quiz.generation.GeneratedQuizValidator;
import studio.thumbsup.server.quiz.generation.QuizGenerationException;
import studio.thumbsup.server.quiz.generation.QuizPersister;

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

    private AuthoringApprovalService approvalService;

    @BeforeEach
    void setUp() {
        approvalService = new AuthoringApprovalService(
                draftService, jobService, validator, quizRepository, quizPersister, Clock.fixed(NOW, ZoneOffset.UTC));
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
        @DisplayName("NEW draft는 quizPersister.persist를 거치고 draft를 승인 상태로 만든다")
        void materializes_new_draft_via_persist() {
            QuizDraft draft = QuizDraft.createNew("운영체제", "{\"quizzes\":[]}", 1L);
            ReflectionTestUtils.setField(draft, "id", 1L);
            given(draftService.getForUpdate(1L)).willReturn(draft);
            GeneratedQuizSet set = new GeneratedQuizSet(List.of());
            given(validator.parse("{\"quizzes\":[]}")).willReturn(set);

            QuizDraft result = approvalService.approve(9L, 1L);

            verify(validator).validateHintSet(set);
            verify(quizPersister).persist("운영체제", set);
            assertThat(result.getStatus()).isEqualTo(QuizDraftStatus.APPROVED);
            assertThat(result.getApprovedBy()).isEqualTo(9L);
        }

        @Test
        @DisplayName("hint가 없는 legacy draft는 materialize 전에 검증 실패한다")
        void rejects_legacy_draft_without_hint_before_persisting() {
            QuizDraft draft = QuizDraft.createNew("운영체제", "{\"quizzes\":[]}", 1L);
            ReflectionTestUtils.setField(draft, "id", 1L);
            given(draftService.getForUpdate(1L)).willReturn(draft);
            GeneratedQuizSet set = new GeneratedQuizSet(List.of());
            given(validator.parse("{\"quizzes\":[]}")).willReturn(set);
            willThrow(new QuizGenerationException("슬롯 1의 hint가 비어 있습니다."))
                    .given(validator)
                    .validateHintSet(set);

            assertThatThrownBy(() -> approvalService.approve(9L, 1L))
                    .isInstanceOf(BusinessException.class)
                    .extracting(exception -> ((BusinessException) exception).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_DRAFT_REVIEW_REQUIRED);

            verify(quizPersister, never()).persist("운영체제", set);
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
}
