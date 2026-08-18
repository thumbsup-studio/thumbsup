package studio.thumbsup.server.quiz.authoring;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.authoring.dto.PublishResponse;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;
import studio.thumbsup.server.quiz.generation.GeneratedQuizValidator;
import studio.thumbsup.server.quiz.generation.QuizPersister;
import studio.thumbsup.server.quiz.generation.QuizPreset;

@ExtendWith(MockitoExtension.class)
class AuthoringPublishServiceTest {

    @Mock
    private AuthoringOutlineRepository outlineRepository;

    @Mock
    private AuthoringOutlineStepRepository stepRepository;

    @Mock
    private QuizDraftRepository draftRepository;

    @Mock
    private CourseRepository courseRepository;

    @Mock
    private GeneratedQuizValidator validator;

    @Mock
    private QuizPersister quizPersister;

    private AuthoringPublishService service;

    @BeforeEach
    void setUp() {
        service = new AuthoringPublishService(
                outlineRepository, stepRepository, draftRepository, courseRepository, validator, quizPersister);
    }

    @Test
    @DisplayName("모든 승인 스텝을 원래 순서대로 한 코스로 발행한다")
    void publishesApprovedStepsInOrder() {
        AuthoringOutline outline = outline(1L);
        AuthoringOutlineStep first = step(11L, 1, "첫째");
        AuthoringOutlineStep second = step(12L, 2, "둘째");
        QuizDraft firstDraft = approvedDraft(21L, "첫째", QuizPreset.BASIC_5, "payload-1");
        QuizDraft secondDraft = approvedDraft(22L, "둘째", QuizPreset.LIGHT_3, "payload-2");
        first.attachDraft(firstDraft.getId());
        second.attachDraft(secondDraft.getId());
        GeneratedQuizSet firstSet = org.mockito.Mockito.mock(GeneratedQuizSet.class);
        GeneratedQuizSet secondSet = org.mockito.Mockito.mock(GeneratedQuizSet.class);
        Course course = course(31L);

        given(outlineRepository.findByIdForUpdate(1L)).willReturn(Optional.of(outline));
        given(stepRepository.findByOutlineIdOrderByOrderNoAsc(1L)).willReturn(List.of(first, second));
        given(draftRepository.findByIdIn(anyCollection())).willReturn(List.of(firstDraft, secondDraft));
        given(validator.parse("payload-1")).willReturn(firstSet);
        given(validator.parse("payload-2")).willReturn(secondSet);
        given(courseRepository.save(any(Course.class))).willReturn(course);
        given(quizPersister.nextStepOrder(31L)).willReturn(8);

        PublishResponse response = service.publish(7L, 1L);

        assertThat(response).isEqualTo(new PublishResponse(31L, 2));
        verify(quizPersister).persistAt(31L, 8, "첫째", 3, firstSet);
        verify(quizPersister).persistAt(31L, 9, "둘째", 2, secondSet);
        assertThat(outline.isPublished()).isTrue();
        assertThat(outline.getPublishedCourseId()).isEqualTo(31L);
    }

    @Test
    @DisplayName("미승인 스텝이 하나라도 있으면 라이브 데이터를 쓰지 않는다")
    void rejectsWhenAnyStepIsNotApproved() {
        AuthoringOutline outline = outline(1L);
        AuthoringOutlineStep step = step(11L, 1, "검토 중");
        QuizDraft draft = QuizDraft.createForOutlineStep("검토 중", "payload", QuizPreset.BASIC_5, 7L);
        ReflectionTestUtils.setField(draft, "id", 21L);
        step.attachDraft(21L);
        given(outlineRepository.findByIdForUpdate(1L)).willReturn(Optional.of(outline));
        given(stepRepository.findByOutlineIdOrderByOrderNoAsc(1L)).willReturn(List.of(step));
        given(draftRepository.findByIdIn(anyCollection())).willReturn(List.of(draft));

        assertThatThrownBy(() -> service.publish(7L, 1L))
                .isInstanceOf(BusinessException.class)
                .extracting(exception -> ((BusinessException) exception).getErrorType())
                .isEqualTo(AuthoringErrorType.AUTHORING_OUTLINE_NOT_READY);
        verify(courseRepository, never()).save(any(Course.class));
        verify(quizPersister, never()).persistAt(any(), any(Integer.class), any(), any(Integer.class), any());
    }

    @Test
    @DisplayName("스텝이 없는 뼈대는 발행할 수 없다")
    void rejectsEmptyOutline() {
        given(outlineRepository.findByIdForUpdate(1L)).willReturn(Optional.of(outline(1L)));
        given(stepRepository.findByOutlineIdOrderByOrderNoAsc(1L)).willReturn(List.of());

        assertThatThrownBy(() -> service.publish(7L, 1L))
                .isInstanceOf(BusinessException.class)
                .extracting(exception -> ((BusinessException) exception).getErrorType())
                .isEqualTo(AuthoringErrorType.AUTHORING_OUTLINE_NOT_READY);
    }

    private static AuthoringOutline outline(Long id) {
        AuthoringOutline outline = AuthoringOutline.create("테스트 코스", "CS", "목차", 7L);
        ReflectionTestUtils.setField(outline, "id", id);
        return outline;
    }

    private static AuthoringOutlineStep step(Long id, int orderNo, String topic) {
        AuthoringOutlineStep step = AuthoringOutlineStep.create(1L, orderNo, topic, "학습 목표");
        ReflectionTestUtils.setField(step, "id", id);
        return step;
    }

    private static QuizDraft approvedDraft(Long id, String topic, QuizPreset preset, String payload) {
        QuizDraft draft = QuizDraft.createForOutlineStep(topic, payload, preset, 7L);
        ReflectionTestUtils.setField(draft, "id", id);
        draft.approve(7L, Instant.parse("2026-08-02T00:00:00Z"));
        return draft;
    }

    private static Course course(Long id) {
        Course course = Course.create("테스트 코스", "CS");
        ReflectionTestUtils.setField(course, "id", id);
        return course;
    }
}
