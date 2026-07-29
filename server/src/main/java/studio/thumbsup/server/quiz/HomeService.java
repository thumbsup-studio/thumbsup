package studio.thumbsup.server.quiz;

import java.time.Clock;
import java.time.LocalDate;
import java.util.Optional;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.time.TimeZones;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.dto.HomeResponse;

/**
 * ⚠️ 클래스 레벨 {@code @Transactional(readOnly = true)}는 조회 전용 기본값이다.
 *
 * <p>"오늘의 학습" 커서는 {@link QuizProgress#getCurrentStepOrder()} 하나뿐이다(#117) — 예전엔
 * 별도 학습 진행 엔티티가 화면용 커서를 따로 들고 있었으나, 퀴즈 진행 상태와 따로 갱신되며 어긋나는
 * 문제가 있어 없앴다. 홈은 이 커서로 {@link QuizStep}을 찾아 표시할 뿐, 커서를 갱신하지 않는다
 * (갱신은 {@link QuizService#advanceProgressIfStepCompleted}의 몫).
 */
@Service
@Transactional(readOnly = true)
public class HomeService {

    private final CourseRepository courseRepository;
    private final QuizStepRepository quizStepRepository;
    private final QuizProgressRepository quizProgressRepository;
    private final UserProgressRepository userProgressRepository;
    private final Clock clock;

    public HomeService(
            CourseRepository courseRepository,
            QuizStepRepository quizStepRepository,
            QuizProgressRepository quizProgressRepository,
            UserProgressRepository userProgressRepository,
            Clock clock) {
        this.courseRepository = courseRepository;
        this.quizStepRepository = quizStepRepository;
        this.quizProgressRepository = quizProgressRepository;
        this.userProgressRepository = userProgressRepository;
        this.clock = clock;
    }

    /**
     * 진행 기록이 없으면(신규 유저) 스트릭 0·포인트 0·그 코스의 첫 스텝부터 시작하는 기본 상태로 응답한다
     * (에러가 아니다 — 앱 홈은 이 상태를 빈 값이 아니라 기본 화면으로 표시한다).
     *
     * <p>{@code courseId}가 null이면 기본 코스({@link CourseRepository#findFirstByOrderByIdAsc})를 쓴다 —
     * 코스 선택 UI가 아직 없는 앱이 courseId 없이 호출해도 기존과 동일하게 동작한다.
     *
     * <p>스트릭·완료 플래그는 배치 없이 이 조회 시점에 KST 기준 오늘 날짜로 그때그때 계산한다
     * ({@link UserProgress#getEffectiveStreak}) — 이틀 이상 건너뛴 스트릭은 DB를 갱신하지 않고
     * 응답에서만 0으로 보여준다.
     */
    public HomeResponse getHome(Long userId, Long courseId) {
        Course course = resolveCourse(courseId);
        Long resolvedCourseId = course.getId();
        long totalCount = quizStepRepository.countByCourseId(resolvedCourseId);
        int minStepOrder = quizStepRepository
                .findMinStepOrderByCourseId(resolvedCourseId)
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));
        int maxStepOrder = quizStepRepository
                .findMaxStepOrderByCourseId(resolvedCourseId)
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));

        int cursor = clamp(currentStepOrder(userId, resolvedCourseId, minStepOrder), maxStepOrder);
        QuizStep step = quizStepRepository
                .findByStepOrder(cursor)
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));

        LocalDate todayKst = LocalDate.now(clock.withZone(TimeZones.KST));
        UserProgress progress = userProgressRepository.findByUserId(userId).orElse(null);
        int streak = progress == null ? 0 : progress.getEffectiveStreak(todayKst);
        int points = progress == null ? 0 : progress.getPoints();
        boolean todayCompleted = progress != null && todayKst.equals(progress.getLastCompletedDate());

        return HomeResponse.from(streak, points, todayCompleted, course, step, minStepOrder, (int) totalCount);
    }

    /** courseId가 지정돼 있으면 그 코스를, 없으면 기본 코스(가장 먼저 생성된 코스)를 가져온다. */
    private Course resolveCourse(Long courseId) {
        Optional<Course> course =
                courseId != null ? courseRepository.findById(courseId) : courseRepository.findFirstByOrderByIdAsc();
        return course.orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));
    }

    private int currentStepOrder(Long userId, Long courseId, int defaultStepOrder) {
        return quizProgressRepository
                .findByUserIdAndCourseId(userId, courseId)
                .map(QuizProgress::getCurrentStepOrder)
                .orElse(defaultStepOrder);
    }

    /** 코스를 완주했으면(커서가 그 코스의 마지막 스텝을 넘으면) 마지막 스텝으로 고정한다. */
    private int clamp(int stepOrder, int maxStepOrder) {
        return Math.min(stepOrder, maxStepOrder);
    }
}
