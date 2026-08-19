package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizFixture;
import studio.thumbsup.server.quiz.QuizStepBriefingBlockType;
import studio.thumbsup.server.quiz.QuizType;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;

@ExtendWith(MockitoExtension.class)
class AuthoringDraftServiceTest {

    @Mock
    private QuizDraftRepository quizDraftRepository;

    @Mock
    private QuizDraftRevisionRepository quizDraftRevisionRepository;

    @Mock
    private AuthoringOutlineRepository outlineRepository;

    @Mock
    private AuthoringOutlineStepRepository outlineStepRepository;

    private final ObjectMapper objectMapper = new ObjectMapper();

    private AuthoringDraftService service() {
        return new AuthoringDraftService(
                quizDraftRepository,
                quizDraftRevisionRepository,
                outlineRepository,
                outlineStepRepository,
                objectMapper);
    }

    private static GeneratedQuizSet.GeneratedQuiz sampleGeneratedQuiz() {
        return new GeneratedQuizSet.GeneratedQuiz(
                QuizType.OX,
                QuizDifficulty.EASY,
                "질문",
                "판단에 필요한 조건을 떠올려 보세요.",
                null,
                "요약",
                null,
                "오답 해설",
                "O",
                null,
                null,
                List.of(),
                List.of("개념"),
                List.of());
    }

    @Nested
    @DisplayName("createFromGenerate")
    class CreateFromGenerate {

        @Test
        @DisplayName("draft를 저장하고 rev1을 남기며 잡에 draftId를 붙인다")
        void saves_draft_rev1_and_attaches_draft_to_job() {
            GenerationJob job = GenerationJob.createGenerate(1L, "운영체제", "prompt");
            ReflectionTestUtils.setField(job, "id", 10L);
            GeneratedQuizSet set = new GeneratedQuizSet(List.of(sampleGeneratedQuiz()));
            given(quizDraftRepository.save(any())).willAnswer(invocation -> {
                QuizDraft draft = invocation.getArgument(0);
                ReflectionTestUtils.setField(draft, "id", 100L);
                return draft;
            });

            QuizDraft draft = service().createFromGenerate(job, set);

            assertThat(draft.getId()).isEqualTo(100L);
            assertThat(draft.getOrigin()).isEqualTo(QuizDraftOrigin.NEW);
            assertThat(draft.getTopic()).isEqualTo("운영체제");

            ArgumentCaptor<QuizDraftRevision> revisionCaptor = ArgumentCaptor.forClass(QuizDraftRevision.class);
            verify(quizDraftRevisionRepository).save(revisionCaptor.capture());
            assertThat(revisionCaptor.getValue().getRevisionNo()).isEqualTo(1);
            assertThat(revisionCaptor.getValue().getDraftId()).isEqualTo(100L);
            assertThat(revisionCaptor.getValue().getJobId()).isEqualTo(10L);

            assertThat(job.getDraftId()).isEqualTo(100L);
        }

        @Test
        @DisplayName("스텝 생성 잡은 OUTLINE_STEP draft를 만들고 뼈대 스텝에 연결한다")
        void creates_outline_step_draft_and_links_step() {
            GenerationJob job = GenerationJob.createStepGenerate(
                    1L, 10L, "프로세스", studio.thumbsup.server.quiz.generation.QuizPreset.LIGHT_3, "prompt");
            ReflectionTestUtils.setField(job, "id", 11L);
            AuthoringOutlineStep step = AuthoringOutlineStep.create(1L, 1, "프로세스", null);
            ReflectionTestUtils.setField(step, "id", 10L);
            given(outlineStepRepository.findById(10L)).willReturn(Optional.of(step));
            // draft를 붙이기 전에 뼈대 행을 잠근다 — 재생성 경로와 직렬화하기 위한 락이다.
            given(outlineRepository.findByIdForUpdate(1L))
                    .willReturn(Optional.of(AuthoringOutline.create("코스", "CS", "목차", 1L)));
            given(quizDraftRepository.save(any())).willAnswer(invocation -> {
                QuizDraft draft = invocation.getArgument(0);
                ReflectionTestUtils.setField(draft, "id", 100L);
                return draft;
            });

            QuizDraft draft = service()
                    .createFromGenerate(
                            job,
                            new GeneratedQuizSet(List.of(sampleGeneratedQuiz())),
                            studio.thumbsup.server.quiz.generation.QuizPreset.LIGHT_3);

            assertThat(draft.getOrigin()).isEqualTo(QuizDraftOrigin.OUTLINE_STEP);
            assertThat(draft.getPreset()).isEqualTo(studio.thumbsup.server.quiz.generation.QuizPreset.LIGHT_3);
            assertThat(step.getDraftId()).isEqualTo(100L);
        }
    }

    @Nested
    @DisplayName("applyReview")
    class ApplyReview {

        @Test
        @DisplayName("currentPayload를 교체하고 기존 최대 revision+1로 저장한다")
        void replaces_payload_and_appends_next_revision() {
            GenerationJob job = GenerationJob.createReview(2L, 200L, "피드백", "prompt");
            ReflectionTestUtils.setField(job, "id", 20L);
            QuizDraft draft = QuizDraft.createNew("운영체제", "{}", 1L);
            ReflectionTestUtils.setField(draft, "id", 200L);
            given(quizDraftRepository.findById(200L)).willReturn(Optional.of(draft));
            given(quizDraftRevisionRepository.findTopByDraftIdOrderByRevisionNoDesc(200L))
                    .willReturn(Optional.of(QuizDraftRevision.create(200L, 3, "{}", null, null, 1L)));

            ReviewResult result = new ReviewResult("무엇을 고쳤는지", List.of(sampleGeneratedQuiz()));

            QuizDraft updated = service().applyReview(job, result);

            assertThat(updated.getCurrentPayload()).contains("\"quizzes\"");

            ArgumentCaptor<QuizDraftRevision> revisionCaptor = ArgumentCaptor.forClass(QuizDraftRevision.class);
            verify(quizDraftRevisionRepository).save(revisionCaptor.capture());
            assertThat(revisionCaptor.getValue().getRevisionNo()).isEqualTo(4);
            assertThat(revisionCaptor.getValue().getReviewSummary()).isEqualTo("무엇을 고쳤는지");
            assertThat(revisionCaptor.getValue().getReviewedBy()).isEqualTo(2L);
            assertThat(revisionCaptor.getValue().getJobId()).isEqualTo(20L);
        }

        @Test
        @DisplayName("이전 revision이 없으면 1부터 시작한다")
        void starts_from_revision_one_when_no_prior_revision() {
            GenerationJob job = GenerationJob.createReview(2L, 201L, "피드백", "prompt");
            ReflectionTestUtils.setField(job, "id", 21L);
            QuizDraft draft = QuizDraft.createNew("운영체제", "{}", 1L);
            ReflectionTestUtils.setField(draft, "id", 201L);
            given(quizDraftRepository.findById(201L)).willReturn(Optional.of(draft));
            given(quizDraftRevisionRepository.findTopByDraftIdOrderByRevisionNoDesc(201L))
                    .willReturn(Optional.empty());

            service().applyReview(job, new ReviewResult("요약", List.of(sampleGeneratedQuiz())));

            ArgumentCaptor<QuizDraftRevision> revisionCaptor = ArgumentCaptor.forClass(QuizDraftRevision.class);
            verify(quizDraftRevisionRepository).save(revisionCaptor.capture());
            assertThat(revisionCaptor.getValue().getRevisionNo()).isEqualTo(1);
        }

        @Test
        @DisplayName("스텝 검수 결과의 브리핑도 revision과 currentPayload에 그대로 보존한다")
        void preserves_briefing_in_review_revision() throws Exception {
            GenerationJob job = GenerationJob.createReview(2L, 202L, "피드백", "prompt");
            ReflectionTestUtils.setField(job, "id", 22L);
            QuizDraft draft = QuizDraft.createNew("운영체제", "{}", 1L);
            ReflectionTestUtils.setField(draft, "id", 202L);
            given(quizDraftRepository.findById(202L)).willReturn(Optional.of(draft));
            given(quizDraftRevisionRepository.findTopByDraftIdOrderByRevisionNoDesc(202L))
                    .willReturn(Optional.empty());
            ReviewResult result = new ReviewResult(
                    "브리핑을 다듬음",
                    GeneratedQuizSet.STEP_BRIEFING_SCHEMA_VERSION,
                    new GeneratedQuizSet.GeneratedBriefing(
                            "요약",
                            List.of(
                                    new GeneratedQuizSet.GeneratedBriefingBlock(
                                            QuizStepBriefingBlockType.CONCEPT, "개념", "개념 설명"),
                                    new GeneratedQuizSet.GeneratedBriefingBlock(
                                            QuizStepBriefingBlockType.CAUTION, "주의", "주의 설명"))),
                    List.of(sampleGeneratedQuiz()));

            QuizDraft updated = service().applyReview(job, result);

            assertThat(objectMapper
                            .readTree(updated.getCurrentPayload())
                            .path("briefing")
                            .path("summary")
                            .asText())
                    .isEqualTo("요약");
            ArgumentCaptor<QuizDraftRevision> revisionCaptor = ArgumentCaptor.forClass(QuizDraftRevision.class);
            verify(quizDraftRevisionRepository).save(revisionCaptor.capture());
            assertThat(objectMapper
                            .readTree(revisionCaptor.getValue().getPayload())
                            .path("briefing")
                            .path("blocks"))
                    .hasSize(2);
        }
    }

    @Nested
    @DisplayName("createImproveDraft")
    class CreateImproveDraft {

        @Test
        @DisplayName("원본 quiz를 GeneratedQuizSet 1개짜리로 감싸 IMPROVE draft를 저장하고 revision은 만들지 않는다")
        void saves_improve_draft_without_revision() {
            Quiz sourceQuiz = QuizFixture.oxQuiz();
            ReflectionTestUtils.setField(sourceQuiz, "id", 5L);
            given(quizDraftRepository.save(any())).willAnswer(invocation -> invocation.getArgument(0));

            QuizDraft draft = service().createImproveDraft(1L, sourceQuiz, "운영체제");

            assertThat(draft.getOrigin()).isEqualTo(QuizDraftOrigin.IMPROVE);
            assertThat(draft.getSourceQuizId()).isEqualTo(5L);
            assertThat(draft.getCurrentPayload()).contains("\"quizzes\"");
            verify(quizDraftRevisionRepository, never()).save(any());
        }
    }

    @Nested
    @DisplayName("getOrThrow")
    class GetOrThrow {

        @Test
        @DisplayName("존재하지 않는 draft면 AUTHORING_DRAFT_NOT_FOUND")
        void throws_when_draft_not_found() {
            given(quizDraftRepository.findById(999L)).willReturn(Optional.empty());

            assertThatThrownBy(() -> service().getOrThrow(999L))
                    .isInstanceOf(BusinessException.class)
                    .extracting(ex -> ((BusinessException) ex).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_DRAFT_NOT_FOUND);
        }
    }

    @Nested
    @DisplayName("getForUpdate")
    class GetForUpdate {

        @Test
        @DisplayName("존재하지 않는 draft면 AUTHORING_DRAFT_NOT_FOUND")
        void throws_when_draft_not_found() {
            given(quizDraftRepository.findByIdForUpdate(999L)).willReturn(Optional.empty());

            assertThatThrownBy(() -> service().getForUpdate(999L))
                    .isInstanceOf(BusinessException.class)
                    .extracting(ex -> ((BusinessException) ex).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_DRAFT_NOT_FOUND);
        }

        @Test
        @DisplayName("잠금 조회 전용 finder(findByIdForUpdate)를 쓴다 — 일반 findById가 아니다(#174 I2)")
        void uses_locking_finder_not_plain_findById() {
            QuizDraft draft = QuizDraft.createNew("운영체제", "{}", 1L);
            ReflectionTestUtils.setField(draft, "id", 1L);
            given(quizDraftRepository.findByIdForUpdate(1L)).willReturn(Optional.of(draft));

            QuizDraft result = service().getForUpdate(1L);

            assertThat(result).isSameAs(draft);
            verify(quizDraftRepository, never()).findById(any());
        }
    }
}
