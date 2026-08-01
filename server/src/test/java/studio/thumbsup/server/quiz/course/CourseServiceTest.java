package studio.thumbsup.server.quiz.course;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;

import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import studio.thumbsup.server.quiz.QuizFixture;
import studio.thumbsup.server.quiz.QuizProgress;
import studio.thumbsup.server.quiz.QuizProgressRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.course.dto.CourseListResponse;
import studio.thumbsup.server.quiz.course.dto.CourseListResponse.StepItem;
import studio.thumbsup.server.quiz.course.dto.CourseListResponse.StepState;

/** Service 단위 테스트 — Spring 없이 Mockito로 스텝 상태(완료/오늘/잠김) 판정 로직만 검증한다 (피라미드 1층). */
@ExtendWith(MockitoExtension.class)
@DisplayName("코스 서비스")
class CourseServiceTest {

    private static final Long USER_ID = 1L;

    @Mock
    private CourseRepository courseRepository;

    @Mock
    private QuizStepRepository quizStepRepository;

    @Mock
    private QuizProgressRepository quizProgressRepository;

    @InjectMocks
    private CourseService courseService;

    @Nested
    @DisplayName("코스 목록 조회")
    class GetCourses {

        @Test
        @DisplayName("진행 기록이 없으면 첫 스텝만 SOLVABLE이고 나머지는 LOCKED다")
        void first_step_is_solvable_without_progress() {
            Course course = QuizFixture.course(1L);
            given(courseRepository.findAllByOrderByIdAsc()).willReturn(List.of(course));
            given(quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(1L)))
                    .willReturn(List.of(
                            QuizStep.create(1, 1L, "스텝1", 5),
                            QuizStep.create(2, 1L, "스텝2", 5),
                            QuizStep.create(3, 1L, "스텝3", 5)));
            given(quizProgressRepository.findByUserIdAndCourseIdIn(USER_ID, List.of(1L)))
                    .willReturn(List.of());

            CourseListResponse response = courseService.getCourses(USER_ID);

            assertThat(response.items().get(0).steps())
                    .extracting(StepItem::state)
                    .containsExactly(StepState.SOLVABLE, StepState.LOCKED, StepState.LOCKED);
        }

        @Test
        @DisplayName("진행 커서 이전은 COMPLETED, 커서는 SOLVABLE, 이후는 LOCKED다")
        void classifies_steps_by_progress_cursor() {
            Course course = QuizFixture.course(1L);
            given(courseRepository.findAllByOrderByIdAsc()).willReturn(List.of(course));
            given(quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(1L)))
                    .willReturn(List.of(
                            QuizStep.create(1, 1L, "스텝1", 5),
                            QuizStep.create(2, 1L, "스텝2", 5),
                            QuizStep.create(3, 1L, "스텝3", 5)));
            given(quizProgressRepository.findByUserIdAndCourseIdIn(USER_ID, List.of(1L)))
                    .willReturn(List.of(QuizProgress.create(USER_ID, 1L, 2)));

            CourseListResponse response = courseService.getCourses(USER_ID);

            assertThat(response.items().get(0).steps())
                    .extracting(StepItem::state)
                    .containsExactly(StepState.COMPLETED, StepState.SOLVABLE, StepState.LOCKED);
        }

        @Test
        @DisplayName("코스를 완주하면(커서가 마지막 스텝을 넘으면) 모든 스텝이 COMPLETED다")
        void all_steps_completed_when_course_finished() {
            Course course = QuizFixture.course(1L);
            given(courseRepository.findAllByOrderByIdAsc()).willReturn(List.of(course));
            given(quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(1L)))
                    .willReturn(List.of(QuizStep.create(1, 1L, "스텝1", 5), QuizStep.create(2, 1L, "스텝2", 5)));
            given(quizProgressRepository.findByUserIdAndCourseIdIn(USER_ID, List.of(1L)))
                    .willReturn(List.of(QuizProgress.create(USER_ID, 1L, 3)));

            CourseListResponse response = courseService.getCourses(USER_ID);

            assertThat(response.items().get(0).steps())
                    .extracting(StepItem::state)
                    .containsExactly(StepState.COMPLETED, StepState.COMPLETED);
        }

        @Test
        @DisplayName("여러 코스의 진행 상태가 서로 섞이지 않는다")
        void does_not_mix_progress_across_courses() {
            Course courseA = QuizFixture.course(1L);
            Course courseB = QuizFixture.course(2L);
            given(courseRepository.findAllByOrderByIdAsc()).willReturn(List.of(courseA, courseB));
            given(quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(1L, 2L)))
                    .willReturn(List.of(
                            QuizStep.create(1, 1L, "A1", 5),
                            QuizStep.create(2, 1L, "A2", 5),
                            QuizStep.create(13, 2L, "B1", 5),
                            QuizStep.create(14, 2L, "B2", 5)));
            given(quizProgressRepository.findByUserIdAndCourseIdIn(USER_ID, List.of(1L, 2L)))
                    .willReturn(List.of(QuizProgress.create(USER_ID, 1L, 2)));

            CourseListResponse response = courseService.getCourses(USER_ID);

            assertThat(response.items().get(0).steps())
                    .extracting(StepItem::state)
                    .containsExactly(StepState.COMPLETED, StepState.SOLVABLE);
            assertThat(response.items().get(1).steps())
                    .extracting(StepItem::state)
                    .containsExactly(StepState.SOLVABLE, StepState.LOCKED);
        }

        @Test
        @DisplayName("코스가 하나도 없으면 빈 목록을 반환한다")
        void returns_empty_list_when_no_courses() {
            given(courseRepository.findAllByOrderByIdAsc()).willReturn(List.of());
            given(quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of()))
                    .willReturn(List.of());
            given(quizProgressRepository.findByUserIdAndCourseIdIn(USER_ID, List.of()))
                    .willReturn(List.of());

            CourseListResponse response = courseService.getCourses(USER_ID);

            assertThat(response.items()).isEmpty();
        }
    }
}
