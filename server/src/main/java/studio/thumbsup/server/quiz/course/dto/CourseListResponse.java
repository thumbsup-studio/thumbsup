package studio.thumbsup.server.quiz.course.dto;

import java.util.List;
import java.util.Map;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.course.Course;

/**
 * GET /api/v1/courses 전용 응답 DTO — 다른 API와 공유하지 않는다.
 * 최상위 컬렉션(코스 목록)의 키는 {@code items}, 코스 안에 딸린 스텝 배열은 무엇을 담았는지 드러나는
 * 이름({@code steps})을 쓴다(docs/api-standard.md §4 — 한 응답에 배열이 여럿이라 전부 items일 수는 없다).
 */
public record CourseListResponse(List<CourseItem> items) {

    public static CourseListResponse from(
            List<Course> courses,
            Map<Long, List<QuizStep>> stepsByCourseId,
            Map<Long, Integer> currentStepOrderByCourseId) {
        List<CourseItem> items = courses.stream()
                .map(course -> CourseItem.from(
                        course,
                        stepsByCourseId.getOrDefault(course.getId(), List.of()),
                        currentStepOrderByCourseId.get(course.getId())))
                .toList();
        return new CourseListResponse(items);
    }

    public record CourseItem(Long courseId, String title, String category, List<StepItem> steps) {

        private static CourseItem from(Course course, List<QuizStep> steps, int currentStepOrder) {
            List<StepItem> stepItems = steps.stream()
                    .map(step -> StepItem.from(step, currentStepOrder))
                    .toList();
            return new CourseItem(course.getId(), course.getTitle(), course.getCategory(), stepItems);
        }
    }

    public record StepItem(int stepOrder, String topic, int estimatedMinutes, StepState state) {

        private static StepItem from(QuizStep step, int currentStepOrder) {
            return new StepItem(
                    step.getStepOrder(),
                    step.getTopic(),
                    step.getEstimatedMinutes(),
                    StepState.resolve(step.getStepOrder(), currentStepOrder));
        }
    }

    /**
     * 스텝 클릭 가능 여부 — {@code QuizProgress#currentStepOrder} 커서와의 비교로만 산출한다.
     * 일일 진행 제한은 없다(하루에 여러 스텝 진행 가능) — "오늘 풀 수 있음"은 날짜가 아니라 커서 위치 기준이다.
     */
    public enum StepState {
        COMPLETED,
        SOLVABLE,
        LOCKED;

        private static StepState resolve(int stepOrder, int currentStepOrder) {
            if (stepOrder < currentStepOrder) {
                return COMPLETED;
            }
            if (stepOrder == currentStepOrder) {
                return SOLVABLE;
            }
            return LOCKED;
        }
    }
}
