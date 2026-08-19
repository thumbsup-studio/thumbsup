package studio.thumbsup.server.quiz;

import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;

/**
 * 일반 학습 진입점이 공유하는 현재 위치 계산. courseId는 코스를 고르고, 결과 stepOrder는 그 코스의 현재
 * 커서를 가리킨다. #292 이후에도 stepOrder의 표시 의미가 바뀔 뿐, 이 계산의 책임은 유지된다.
 */
final class CurrentQuizStepResolver {

    private CurrentQuizStepResolver() {}

    static CurrentQuizStep resolve(
            Long userId,
            Long requestedCourseId,
            CourseRepository courseRepository,
            QuizProgressRepository quizProgressRepository,
            QuizStepRepository quizStepRepository) {
        Long courseId = resolveCourseId(requestedCourseId, courseRepository);
        int stepOrder = quizProgressRepository
                .findByUserIdAndCourseId(userId, courseId)
                .map(QuizProgress::getCurrentStepOrder)
                .orElseGet(() -> initialStepOrder(courseId, quizStepRepository));

        int maxStepOrder = quizStepRepository
                .findMaxStepOrderByCourseId(courseId)
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
        if (stepOrder > maxStepOrder) {
            throw new BusinessException(QuizErrorType.QUIZ_STEP_COMPLETED);
        }
        return new CurrentQuizStep(courseId, stepOrder);
    }

    private static Long resolveCourseId(Long requestedCourseId, CourseRepository courseRepository) {
        if (requestedCourseId != null) {
            return requestedCourseId;
        }
        return courseRepository
                .findFirstByOrderByIdAsc()
                .map(Course::getId)
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));
    }

    private static int initialStepOrder(Long courseId, QuizStepRepository quizStepRepository) {
        return quizStepRepository
                .findMinStepOrderByCourseId(courseId)
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
    }

    record CurrentQuizStep(Long courseId, int stepOrder) {}
}
