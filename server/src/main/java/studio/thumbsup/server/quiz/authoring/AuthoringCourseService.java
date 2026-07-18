package studio.thumbsup.server.quiz.authoring;

import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.Course;
import studio.thumbsup.server.quiz.CourseRepository;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseDetailResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseListResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringDetailedQuizResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringDetailedStepResponse;

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

        Map<Integer, String> topicByStepOrder = quizStepRepository.findAll().stream()
                .collect(Collectors.toMap(QuizStep::getStepOrder, QuizStep::getTopic));

        // quiz_step에 course FK가 아직 없어 지금은 모든 스텝을 반환한다(코스 1개 전제).
        // FK 도입 시 여기서 courseId로 스텝을 필터한다(#182 forward-compat seam).
        Map<Integer, List<Quiz>> quizzesByStep = quizRepository.findAll().stream()
                .filter(quiz -> quiz.getStepOrder() > 0) // 0은 "스텝 밖" placeholder sentinel
                .sorted(Comparator.comparingInt(Quiz::getStepOrder).thenComparingInt(Quiz::getSlotOrder))
                .collect(Collectors.groupingBy(Quiz::getStepOrder, LinkedHashMap::new, Collectors.toList()));

        List<AuthoringDetailedStepResponse> steps = quizzesByStep.entrySet().stream()
                .map(entry -> toDetailedStep(entry.getKey(), entry.getValue(), topicByStepOrder))
                .toList();
        return new AuthoringCourseDetailResponse(course.getId(), course.getTitle(), steps);
    }

    private AuthoringDetailedStepResponse toDetailedStep(
            int stepOrder, List<Quiz> quizzes, Map<Integer, String> topicByStepOrder) {
        String topic = Optional.ofNullable(topicByStepOrder.get(stepOrder)).orElse(null);
        List<AuthoringDetailedQuizResponse> detailed = quizzes.stream()
                .map(quiz -> new AuthoringDetailedQuizResponse(
                        quiz.getId(), quiz.getSlotOrder(), QuizToGeneratedQuizMapper.toGenerated(quiz)))
                .toList();
        return new AuthoringDetailedStepResponse(stepOrder, topic, detailed);
    }
}
