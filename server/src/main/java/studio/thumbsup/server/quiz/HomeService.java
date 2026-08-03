package studio.thumbsup.server.quiz;

import java.time.Clock;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.time.TimeZones;
import studio.thumbsup.server.common.user.UserProgressPort;
import studio.thumbsup.server.common.user.UserProgressSnapshot;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.dto.HomeResponse;
import studio.thumbsup.server.quiz.dto.HomeResponse.CourseLearning;

/**
 * ⚠️ 클래스 레벨 {@code @Transactional(readOnly = true)}는 조회 전용 기본값이다.
 *
 * <p>코스별 학습 커서는 {@link QuizProgress#getCurrentStepOrder()} 하나뿐이다(#117) — 예전엔
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
    private final UserProgressPort userProgressPort;
    private final Clock clock;

    public HomeService(
            CourseRepository courseRepository,
            QuizStepRepository quizStepRepository,
            QuizProgressRepository quizProgressRepository,
            UserProgressPort userProgressPort,
            Clock clock) {
        this.courseRepository = courseRepository;
        this.quizStepRepository = quizStepRepository;
        this.quizProgressRepository = quizProgressRepository;
        this.userProgressPort = userProgressPort;
        this.clock = clock;
    }

    /**
     * 유저가 진행 중인(첫 답안을 제출한) 코스를 최근 푼 순으로 최대 10개 반환한다(#240). 진행 기록이
     * 없으면(신규 유저) 첫 번째 코스(id 최솟값)를 목록에 담아, 스트릭 0·포인트 0·그 코스의 첫 스텝부터
     * 시작하는 기본 상태로 응답한다 (에러가 아니다 — 앱 홈은 이 상태를 기본 화면으로 표시한다).
     *
     * <p>스트릭·완료 플래그는 배치 없이 이 조회 시점에 KST 기준 오늘 날짜로 그때그때 계산한다
     * ({@link UserProgressPort#getSnapshot}) — 이틀 이상 건너뛴 스트릭은 DB를 갱신하지 않고
     * 응답에서만 0으로 보여준다.
     */
    public HomeResponse getHome(Long userId) {
        List<QuizProgress> progresses = quizProgressRepository.findTop10ByUserIdOrderByUpdatedAtDescIdDesc(userId);
        List<CourseLearning> courses = assembleCourses(progresses);
        if (courses.isEmpty()) {
            courses = List.of(defaultCourse());
        }

        LocalDate todayKst = LocalDate.now(clock.withZone(TimeZones.KST));
        UserProgressSnapshot progress = userProgressPort.getSnapshot(userId, todayKst);

        return new HomeResponse(progress.streak(), progress.points(), progress.todayCompleted(), courses);
    }

    /** 진행 순서를 유지한 채 코스·스텝을 in절 일괄 조회로 조립한다 — 루프 안 단건 조회(N+1) 금지. */
    private List<CourseLearning> assembleCourses(List<QuizProgress> progresses) {
        if (progresses.isEmpty()) {
            return List.of();
        }
        List<Long> courseIds =
                progresses.stream().map(QuizProgress::getCourseId).toList();
        Map<Long, Course> coursesById = courseRepository.findAllById(courseIds).stream()
                .collect(Collectors.toMap(Course::getId, Function.identity()));
        Map<Long, List<QuizStep>> stepsByCourseId =
                quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(courseIds).stream()
                        .collect(Collectors.groupingBy(QuizStep::getCourseId));

        List<CourseLearning> courses = new ArrayList<>();
        for (QuizProgress progress : progresses) {
            Course course = coursesById.get(progress.getCourseId());
            List<QuizStep> steps = stepsByCourseId.getOrDefault(progress.getCourseId(), List.of());
            toCourseLearning(course, steps, progress.getCurrentStepOrder()).ifPresent(courses::add);
        }
        return courses;
    }

    /**
     * 코스가 삭제됐거나 스텝이 비었거나 커서 위치의 스텝이 없으면 그 코스만 조용히 목록에서 뺀다 —
     * 항목 하나의 데이터 이상으로 홈 전체를 404로 만들지 않는다.
     */
    private Optional<CourseLearning> toCourseLearning(Course course, List<QuizStep> steps, int cursorStepOrder) {
        if (course == null || steps.isEmpty()) {
            return Optional.empty();
        }
        int minStepOrder = steps.get(0).getStepOrder();
        int maxStepOrder = steps.get(steps.size() - 1).getStepOrder();
        int cursor = clamp(cursorStepOrder, maxStepOrder);
        return steps.stream()
                .filter(step -> step.getStepOrder() == cursor)
                .findFirst()
                .map(step -> CourseLearning.of(course, step, minStepOrder, steps.size()));
    }

    /**
     * 신규 유저(또는 진행 코스가 전부 삭제된 유저) 폴백 — 첫 번째 코스(id 최솟값)의 첫 스텝.
     * 코스나 스텝이 아예 없으면 운영 설정 누락이므로 COURSE_NOT_FOUND로 알린다.
     *
     * <p>유일한 진행 코스가 데이터 이상으로 skip된 유저는 이 폴백에 걸려 실제 진행이 "첫 스텝·완료 0"으로
     * 보일 수 있다 — 깨진 데이터를 404 대신 기본 화면으로 흡수하는 의도된 표시 정책이다.
     */
    private CourseLearning defaultCourse() {
        Course course = courseRepository
                .findFirstByOrderByIdAsc()
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));
        List<QuizStep> steps =
                quizStepRepository.findByCourseIdInOrderByCourseIdAscStepOrderAsc(List.of(course.getId()));
        int firstStepOrder = steps.isEmpty() ? 0 : steps.get(0).getStepOrder();
        return toCourseLearning(course, steps, firstStepOrder)
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));
    }

    /** 코스를 완주했으면(커서가 그 코스의 마지막 스텝을 넘으면) 마지막 스텝으로 고정한다. */
    private int clamp(int stepOrder, int maxStepOrder) {
        return Math.min(stepOrder, maxStepOrder);
    }
}
