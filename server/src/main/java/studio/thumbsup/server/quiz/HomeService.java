package studio.thumbsup.server.quiz;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
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

    private static final int INITIAL_STEP_ORDER = 1;

    private final CourseRepository courseRepository;
    private final QuizStepRepository quizStepRepository;
    private final QuizProgressRepository quizProgressRepository;
    private final UserProgressRepository userProgressRepository;

    public HomeService(
            CourseRepository courseRepository,
            QuizStepRepository quizStepRepository,
            QuizProgressRepository quizProgressRepository,
            UserProgressRepository userProgressRepository) {
        this.courseRepository = courseRepository;
        this.quizStepRepository = quizStepRepository;
        this.quizProgressRepository = quizProgressRepository;
        this.userProgressRepository = userProgressRepository;
    }

    /**
     * 진행 기록이 없으면(신규 유저) 스트릭 0·포인트 0·1스텝부터 시작하는 기본 상태로 응답한다
     * (에러가 아니다 — 앱 홈은 이 상태를 빈 값이 아니라 기본 화면으로 표시한다).
     */
    public HomeResponse getHome(Long userId) {
        Course course = courseRepository
                .findFirstByOrderByIdAsc()
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));
        long totalCount = quizStepRepository.countByStepOrderGreaterThan(0);

        int cursor = clamp(currentStepOrder(userId), totalCount);
        QuizStep step = quizStepRepository
                .findByStepOrder(cursor)
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));

        UserProgress progress = userProgressRepository.findByUserId(userId).orElse(null);
        int streak = progress == null ? 0 : progress.getStreak();
        int points = progress == null ? 0 : progress.getPoints();

        return HomeResponse.from(streak, points, course, step, (int) totalCount);
    }

    private int currentStepOrder(Long userId) {
        return quizProgressRepository
                .findByUserId(userId)
                .map(QuizProgress::getCurrentStepOrder)
                .orElse(INITIAL_STEP_ORDER);
    }

    /** 코스를 완주했으면(커서가 전체 스텝 수를 넘으면) 마지막 스텝으로 고정한다. */
    private int clamp(int stepOrder, long totalCount) {
        if (totalCount <= 0) {
            return stepOrder;
        }
        return Math.min(stepOrder, (int) totalCount);
    }
}
