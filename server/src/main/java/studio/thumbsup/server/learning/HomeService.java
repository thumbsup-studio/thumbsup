package studio.thumbsup.server.learning;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.learning.dto.HomeResponse;

/**
 * ⚠️ 클래스 레벨 {@code @Transactional(readOnly = true)}는 조회 전용 기본값이다.
 * 이 PR은 조회만 다룬다 — streak/points 증가(쓰기) 로직은 후속 티켓의 몫이다.
 */
@Service
@Transactional(readOnly = true)
public class HomeService {

    private static final int INITIAL_CURSOR_UNIT_INDEX = 1;

    private final CourseRepository courseRepository;
    private final UnitRepository unitRepository;
    private final UserProgressRepository userProgressRepository;

    public HomeService(
            CourseRepository courseRepository,
            UnitRepository unitRepository,
            UserProgressRepository userProgressRepository) {
        this.courseRepository = courseRepository;
        this.unitRepository = unitRepository;
        this.userProgressRepository = userProgressRepository;
    }

    /**
     * 유저의 학습 진행 기록이 없으면(신규 유저) 스트릭 0·포인트 0·1화부터 시작하는 기본 상태로 응답한다
     * (에러가 아니다 — 앱 홈은 이 상태를 빈 값이 아니라 기본 화면으로 표시한다).
     */
    public HomeResponse getHome(Long userId) {
        Course course = courseRepository
                .findFirstByOrderByIdAsc()
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));
        long totalCount = unitRepository.countByCourseId(course.getId());

        return userProgressRepository
                .findByUserId(userId)
                .map(progress -> buildFromProgress(progress, course, totalCount))
                .orElseGet(() -> buildDefault(course, totalCount));
    }

    private HomeResponse buildFromProgress(UserProgress progress, Course course, long totalCount) {
        int cursor = clamp(progress.getCursorUnitIndex(), totalCount);
        Unit current = currentUnit(course.getId(), cursor);
        return HomeResponse.from(progress.getStreak(), progress.getPoints(), course, current, (int) totalCount);
    }

    private HomeResponse buildDefault(Course course, long totalCount) {
        int cursor = clamp(INITIAL_CURSOR_UNIT_INDEX, totalCount);
        Unit current = currentUnit(course.getId(), cursor);
        return HomeResponse.from(0, 0, course, current, (int) totalCount);
    }

    /** 코스를 완주했으면(cursor가 전체 화 수를 넘으면) 마지막 화로 고정한다. */
    private int clamp(int cursorUnitIndex, long totalCount) {
        if (totalCount <= 0) {
            return cursorUnitIndex;
        }
        return Math.min(cursorUnitIndex, (int) totalCount);
    }

    private Unit currentUnit(Long courseId, int orderIndex) {
        return unitRepository
                .findByCourseIdAndOrderIndex(courseId, orderIndex)
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));
    }
}
