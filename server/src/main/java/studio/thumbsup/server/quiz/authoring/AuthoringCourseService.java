package studio.thumbsup.server.quiz.authoring;

import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseDetailResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseListResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringDetailedQuizResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringDetailedStepResponse;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;

/**
 * 코스 인덱스·코스별 라이브 문제 상세 조회(#182). 라이브 문제의 전체 상세를 읽기 전용으로 훑는 용도라
 * draft/잡과 무관한 별도 서비스로 둔다.
 */
@Service
@Transactional(readOnly = true)
public class AuthoringCourseService {

    private final CourseRepository courseRepository;
    private final QuizRepository quizRepository;
    private final QuizStepRepository quizStepRepository;

    public AuthoringCourseService(
            CourseRepository courseRepository, QuizRepository quizRepository, QuizStepRepository quizStepRepository) {
        this.courseRepository = courseRepository;
        this.quizRepository = quizRepository;
        this.quizStepRepository = quizStepRepository;
    }

    public AuthoringCourseListResponse listCourses() {
        return new AuthoringCourseListResponse(courseRepository.findAll().stream()
                .map(AuthoringCourseResponse::from)
                .toList());
    }

    public AuthoringCourseDetailResponse getCourseQuizzes(Long courseId) {
        Course course = courseRepository
                .findById(courseId)
                .orElseThrow(() -> new BusinessException(AuthoringErrorType.AUTHORING_COURSE_NOT_FOUND));

        // #292: step_order는 코스마다 겹칠 수 있어 이 코스 소속 스텝만 courseId로 먼저 조회하고,
        // 그 스텝들의 quizStepId(PK)로 문제를 묶는다 — 다른 코스의 같은 stepOrder와 섞이지 않는다.
        List<QuizStep> steps = quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(courseId));
        Map<Long, List<Quiz>> quizzesByStepId =
                quizRepository
                        .findByQuizStepIdIn(steps.stream().map(QuizStep::getId).toList())
                        .stream()
                        .sorted(Comparator.comparingInt(Quiz::getSlotOrder))
                        .collect(Collectors.groupingBy(Quiz::getQuizStepId, LinkedHashMap::new, Collectors.toList()));

        List<AuthoringDetailedStepResponse> stepResponses = steps.stream()
                .map(step -> toDetailedStep(step, quizzesByStepId.getOrDefault(step.getId(), List.of())))
                .toList();
        return new AuthoringCourseDetailResponse(course.getId(), course.getTitle(), stepResponses);
    }

    private AuthoringDetailedStepResponse toDetailedStep(QuizStep step, List<Quiz> quizzes) {
        List<AuthoringDetailedQuizResponse> detailed = quizzes.stream()
                .map(quiz -> new AuthoringDetailedQuizResponse(
                        quiz.getId(), quiz.getSlotOrder(), QuizToGeneratedQuizMapper.toGenerated(quiz)))
                .toList();
        return new AuthoringDetailedStepResponse(step.getStepOrder(), step.getTopic(), detailed);
    }
}
