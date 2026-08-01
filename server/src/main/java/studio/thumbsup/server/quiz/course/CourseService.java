package studio.thumbsup.server.quiz.course;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.quiz.QuizProgress;
import studio.thumbsup.server.quiz.QuizProgressRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.course.dto.CourseListResponse;

/**
 * ⚠️ 클래스 레벨 {@code @Transactional(readOnly = true)}는 조회 전용 기본값이다.
 *
 * <p>코스별 "오늘 풀 수 있는 스텝"은 {@link QuizProgress#getCurrentStepOrder()} 하나로만 판정한다(#117, #247) —
 * 진행 기록이 없는 코스는 그 코스의 첫 스텝을 커서로 간주한다(HomeService·QuizService와 동일 규칙).
 */
@Service
@Transactional(readOnly = true)
public class CourseService {

    private final CourseRepository courseRepository;
    private final QuizStepRepository quizStepRepository;
    private final QuizProgressRepository quizProgressRepository;

    public CourseService(
            CourseRepository courseRepository,
            QuizStepRepository quizStepRepository,
            QuizProgressRepository quizProgressRepository) {
        this.courseRepository = courseRepository;
        this.quizStepRepository = quizStepRepository;
        this.quizProgressRepository = quizProgressRepository;
    }

    public CourseListResponse getCourses(Long userId) {
        List<Course> courses = courseRepository.findAllByOrderByIdAsc();
        List<Long> courseIds = courses.stream().map(Course::getId).toList();

        Map<Long, List<QuizStep>> stepsByCourseId =
                quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(courseIds).stream()
                        .collect(Collectors.groupingBy(QuizStep::getCourseId, LinkedHashMap::new, Collectors.toList()));

        Map<Long, Integer> progressCursorByCourseId =
                quizProgressRepository.findByUserIdAndCourseIdIn(userId, courseIds).stream()
                        .collect(Collectors.toMap(QuizProgress::getCourseId, QuizProgress::getCurrentStepOrder));

        Map<Long, Integer> currentStepOrderByCourseId = new LinkedHashMap<>();
        for (Course course : courses) {
            List<QuizStep> steps = stepsByCourseId.getOrDefault(course.getId(), List.of());
            int defaultStepOrder = steps.isEmpty() ? 0 : steps.get(0).getStepOrder();
            currentStepOrderByCourseId.put(
                    course.getId(), progressCursorByCourseId.getOrDefault(course.getId(), defaultStepOrder));
        }

        return CourseListResponse.from(courses, stepsByCourseId, currentStepOrderByCourseId);
    }
}
