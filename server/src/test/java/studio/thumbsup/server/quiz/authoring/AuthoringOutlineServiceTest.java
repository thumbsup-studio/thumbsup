package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

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
import studio.thumbsup.server.common.exception.CommonErrorType;
import studio.thumbsup.server.quiz.authoring.dto.OutlineCreatedResponse;
import studio.thumbsup.server.quiz.authoring.dto.OutlineDetailResponse;
import studio.thumbsup.server.quiz.authoring.dto.OutlineStepResponse;

@ExtendWith(MockitoExtension.class)
class AuthoringOutlineServiceTest {

    @Mock
    private AuthoringOutlineRepository outlineRepository;

    @Mock
    private AuthoringOutlineStepRepository stepRepository;

    @Mock
    private QuizDraftRepository draftRepository;

    @Mock
    private GenerationJobRepository jobRepository;

    @Mock
    private AuthoringJobService jobService;

    private AuthoringOutlineService service;

    @BeforeEach
    void setUp() {
        service = new AuthoringOutlineService(
                outlineRepository, stepRepository, draftRepository, jobRepository, jobService);
    }

    @Test
    @DisplayName("뼈대를 저장한 뒤 OUTLINE 잡을 큐에 넣고 두 ID를 반환한다")
    void creates_outline_and_enqueues_outline_job() {
        AuthoringOutline outline = outline(10L);
        given(outlineRepository.save(any(AuthoringOutline.class))).willReturn(outline);
        given(jobService.enqueueOutline(7L, 10L)).willReturn(101L);

        OutlineCreatedResponse response = service.createOutline(7L, "네트워크", "CS", "1장 네트워크");

        assertThat(response.outlineId()).isEqualTo(10L);
        assertThat(response.jobId()).isEqualTo(101L);
        verify(jobService).enqueueOutline(7L, 10L);
    }

    @Nested
    @DisplayName("스텝 채움 상태 파생은")
    class FillState {

        @Test
        @DisplayName("draft가 없고 활성 잡도 없으면 EMPTY다")
        void empty() {
            OutlineDetailResponse response = detailWith(step(1L, 1, "프로세스", null), List.of(), List.of());

            assertThat(response.steps().get(0).fillState()).isEqualTo(OutlineStepFillState.EMPTY);
            assertThat(response.steps().get(0).draftId()).isNull();
            assertThat(response.steps().get(0).activeJobId()).isNull();
        }

        @Test
        @DisplayName("draft가 없고 활성 GENERATE 잡이 있으면 GENERATING이고 activeJobId를 함께 준다")
        void generating() {
            AuthoringOutlineStep step = step(1L, 1, "프로세스", null);
            GenerationJob job = GenerationJob.createStepGenerate(
                    7L, 1L, "프로세스", studio.thumbsup.server.quiz.generation.QuizPreset.LIGHT_3, "prompt");
            ReflectionTestUtils.setField(job, "id", 20L);

            OutlineDetailResponse response = detailWith(step, List.of(), List.of(job));

            OutlineStepResponse stepResponse = response.steps().get(0);
            assertThat(stepResponse.fillState()).isEqualTo(OutlineStepFillState.GENERATING);
            assertThat(stepResponse.activeJobId()).isEqualTo(20L);
        }

        @Test
        @DisplayName("draft가 DRAFT면 REVIEWING이다")
        void reviewing() {
            AuthoringOutlineStep step = step(1L, 1, "프로세스", null);
            QuizDraft draft = QuizDraft.createNew("프로세스", "{}", 7L);
            ReflectionTestUtils.setField(draft, "id", 30L);
            step.attachDraft(30L);

            OutlineDetailResponse response = detailWith(step, List.of(draft), List.of());

            assertThat(response.steps().get(0).fillState()).isEqualTo(OutlineStepFillState.REVIEWING);
            assertThat(response.steps().get(0).draftId()).isEqualTo(30L);
        }

        @Test
        @DisplayName("draft가 APPROVED면 APPROVED다")
        void approved() {
            AuthoringOutlineStep step = step(1L, 1, "프로세스", null);
            QuizDraft draft = QuizDraft.createNew("프로세스", "{}", 7L);
            ReflectionTestUtils.setField(draft, "id", 30L);
            draft.approve(7L, java.time.Instant.parse("2026-08-02T00:00:00Z"));
            step.attachDraft(30L);

            OutlineDetailResponse response = detailWith(step, List.of(draft), List.of());

            assertThat(response.steps().get(0).fillState()).isEqualTo(OutlineStepFillState.APPROVED);
        }
    }

    @Nested
    @DisplayName("순서 변경은")
    class Reorder {

        @Test
        @DisplayName("UP이면 앞 스텝과 order_no를 맞바꾼다")
        void swapsWithPrevious() {
            AuthoringOutline outline = outline(1L);
            AuthoringOutlineStep first = step(1L, 1, "첫째", null);
            AuthoringOutlineStep second = step(2L, 2, "둘째", null);
            AuthoringOutlineStep third = step(3L, 3, "셋째", null);
            given(outlineRepository.findByIdForUpdate(1L)).willReturn(Optional.of(outline));
            given(stepRepository.findById(3L)).willReturn(Optional.of(third));
            given(stepRepository.findByOutlineIdOrderByOrderNoAsc(1L)).willReturn(List.of(first, second, third));

            service.reorderStep(3L, "UP");

            assertThat(first.getOrderNo()).isEqualTo(1);
            assertThat(second.getOrderNo()).isEqualTo(3);
            assertThat(third.getOrderNo()).isEqualTo(2);
            verify(stepRepository, org.mockito.Mockito.times(3)).flush();
        }

        @Test
        @DisplayName("첫 스텝 UP은 400이다")
        void rejectsUpOnFirst() {
            given(outlineRepository.findByIdForUpdate(1L)).willReturn(Optional.of(outline(1L)));
            AuthoringOutlineStep first = step(1L, 1, "첫째", null);
            given(stepRepository.findById(1L)).willReturn(Optional.of(first));
            given(stepRepository.findByOutlineIdOrderByOrderNoAsc(1L)).willReturn(List.of(first));

            assertThatThrownBy(() -> service.reorderStep(1L, "UP"))
                    .isInstanceOf(BusinessException.class)
                    .extracting(exception -> ((BusinessException) exception).getErrorType())
                    .isEqualTo(CommonErrorType.INVALID_INPUT);
        }

        @Test
        @DisplayName("마지막 스텝 DOWN은 400이다")
        void rejectsDownOnLast() {
            AuthoringOutlineStep first = step(1L, 1, "첫째", null);
            AuthoringOutlineStep last = step(2L, 2, "마지막", null);
            given(outlineRepository.findByIdForUpdate(1L)).willReturn(Optional.of(outline(1L)));
            given(stepRepository.findById(2L)).willReturn(Optional.of(last));
            given(stepRepository.findByOutlineIdOrderByOrderNoAsc(1L)).willReturn(List.of(first, last));

            assertThatThrownBy(() -> service.reorderStep(2L, "DOWN"))
                    .isInstanceOf(BusinessException.class)
                    .extracting(exception -> ((BusinessException) exception).getErrorType())
                    .isEqualTo(CommonErrorType.INVALID_INPUT);
        }
    }

    @Nested
    @DisplayName("스텝 삭제는")
    class DeleteStep {

        @Test
        @DisplayName("EMPTY 스텝은 삭제된다")
        void deletesEmpty() {
            AuthoringOutlineStep step = step(1L, 1, "빈 스텝", null);
            given(outlineRepository.findByIdForUpdate(1L)).willReturn(Optional.of(outline(1L)));
            given(stepRepository.findById(1L)).willReturn(Optional.of(step));
            given(jobRepository.findByOutlineStepIdAndStatusIn(eq(1L), any())).willReturn(List.of());

            service.deleteStep(1L);

            verify(stepRepository).delete(step);
        }

        @Test
        @DisplayName("REVIEWING 스텝은 삭제하되 draft는 남긴다")
        void keepsDraftWhenDeletingReviewing() {
            AuthoringOutlineStep step = step(1L, 1, "검토 중", null);
            QuizDraft draft = QuizDraft.createNew("검토 중", "{}", 7L);
            ReflectionTestUtils.setField(draft, "id", 11L);
            step.attachDraft(11L);
            given(outlineRepository.findByIdForUpdate(1L)).willReturn(Optional.of(outline(1L)));
            given(stepRepository.findById(1L)).willReturn(Optional.of(step));
            given(draftRepository.findById(11L)).willReturn(Optional.of(draft));
            given(jobRepository.findByOutlineStepIdAndStatusIn(eq(1L), any())).willReturn(List.of());

            service.deleteStep(1L);

            verify(stepRepository).delete(step);
            verify(draftRepository, never()).delete(any());
        }

        @Test
        @DisplayName("APPROVED 스텝은 409다")
        void rejectsApproved() {
            AuthoringOutlineStep step = step(1L, 1, "승인됨", null);
            QuizDraft draft = QuizDraft.createNew("승인됨", "{}", 7L);
            ReflectionTestUtils.setField(draft, "id", 11L);
            draft.approve(7L, java.time.Instant.parse("2026-08-02T00:00:00Z"));
            step.attachDraft(11L);
            given(outlineRepository.findByIdForUpdate(1L)).willReturn(Optional.of(outline(1L)));
            given(stepRepository.findById(1L)).willReturn(Optional.of(step));
            given(draftRepository.findById(11L)).willReturn(Optional.of(draft));

            assertThatThrownBy(() -> service.deleteStep(1L))
                    .isInstanceOf(BusinessException.class)
                    .extracting(exception -> ((BusinessException) exception).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_OUTLINE_STEP_FILLED);
            verify(stepRepository, never()).delete(any());
        }

        @Test
        @DisplayName("활성 잡이 있으면 409다")
        void rejectsWhenJobActive() {
            AuthoringOutlineStep step = step(1L, 1, "생성 중", null);
            GenerationJob job = GenerationJob.createStepGenerate(
                    7L, 1L, "생성 중", studio.thumbsup.server.quiz.generation.QuizPreset.BASIC_5, "prompt");
            given(outlineRepository.findByIdForUpdate(1L)).willReturn(Optional.of(outline(1L)));
            given(stepRepository.findById(1L)).willReturn(Optional.of(step));
            given(jobRepository.findByOutlineStepIdAndStatusIn(eq(1L), any())).willReturn(List.of(job));

            assertThatThrownBy(() -> service.deleteStep(1L))
                    .isInstanceOf(BusinessException.class)
                    .extracting(exception -> ((BusinessException) exception).getErrorType())
                    .isEqualTo(AuthoringErrorType.AUTHORING_DRAFT_JOB_ACTIVE);
            verify(stepRepository, never()).delete(any());
        }
    }

    @Test
    @DisplayName("발행된 뼈대는 제목 수정도 409다")
    void rejectsWritesOnPublishedOutline() {
        AuthoringOutline published = outline(1L);
        published.markPublished(99L);
        given(outlineRepository.findByIdForUpdate(1L)).willReturn(Optional.of(published));

        assertThatThrownBy(() -> service.updateOutline(1L, "새 제목", null))
                .isInstanceOf(BusinessException.class)
                .extracting(exception -> ((BusinessException) exception).getErrorType())
                .isEqualTo(AuthoringErrorType.AUTHORING_OUTLINE_PUBLISHED);
        verify(outlineRepository, never()).save(any());
    }

    private OutlineDetailResponse detailWith(
            AuthoringOutlineStep step, List<QuizDraft> drafts, List<GenerationJob> activeJobs) {
        given(outlineRepository.findById(1L)).willReturn(Optional.of(outline(1L)));
        given(stepRepository.findByOutlineIdOrderByOrderNoAsc(1L)).willReturn(List.of(step));
        if (!drafts.isEmpty()) {
            given(draftRepository.findByIdIn(any())).willReturn(drafts);
        }
        given(jobRepository.findByOutlineStepIdInAndStatusIn(any(), any())).willReturn(activeJobs);
        return service.getDetail(1L);
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
