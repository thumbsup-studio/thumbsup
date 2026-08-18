package studio.thumbsup.server.quiz;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface QuizStepRepository extends JpaRepository<QuizStep, Long> {

    /** 코스 내 상대 순번으로 스텝 하나를 찾는다(#292) — step_order는 코스마다 겹칠 수 있어 courseId와 함께 조회한다. */
    Optional<QuizStep> findByCourseIdAndStepOrder(Long courseId, int stepOrder);

    /**
     * 코스 목록 조회(#247) — 여러 코스의 스텝을 한 번에 가져와 코스별로 묶기 좋게 정렬해 반환한다.
     * stepOrder=0(quiz FK 제약을 만족시키기 위한 "(미배정)" sentinel, #257)은 실제 커리큘럼이 아니므로 제외한다.
     */
    @Query("SELECT s FROM QuizStep s WHERE s.courseId IN :courseIds AND s.stepOrder > 0 "
            + "ORDER BY s.courseId ASC, s.stepOrder ASC")
    List<QuizStep> findByCourseIdInOrderByCourseIdAscStepOrderAsc(Collection<Long> courseIds);

    /** 완료한 스텝 이력 조회용 — startInclusive > endInclusive면(완료한 스텝 없음) 빈 목록을 반환한다. */
    List<QuizStep> findByCourseIdAndStepOrderBetweenOrderByStepOrderAsc(
            Long courseId, int startInclusive, int endInclusive);

    /**
     * 코스의 "시작 스텝" — 실제 커리큘럼은 항상 1부터 시작하지만(#292), 데이터 이상으로 1번이 빠져 있어도
     * 방어적으로 최솟값을 조회한다. 진행 기록이 없는 신규 유저의 기본 커서를 정하는 데 쓴다.
     * stepOrder=0(quiz FK 제약을 만족시키기 위한 "(미배정)" sentinel, #257)은 제외한다.
     */
    @Query("SELECT MIN(s.stepOrder) FROM QuizStep s WHERE s.courseId = :courseId AND s.stepOrder > 0")
    Optional<Integer> findMinStepOrderByCourseId(Long courseId);

    /** 코스의 "마지막 스텝" — 홈 화면 커서를 그 코스의 범위 안으로 clamp하거나, 다음 생성분의 스텝 번호 계산에 쓴다. */
    @Query("SELECT MAX(s.stepOrder) FROM QuizStep s WHERE s.courseId = :courseId")
    Optional<Integer> findMaxStepOrderByCourseId(Long courseId);
}
