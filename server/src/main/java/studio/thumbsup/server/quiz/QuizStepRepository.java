package studio.thumbsup.server.quiz;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface QuizStepRepository extends JpaRepository<QuizStep, Long> {

    Optional<QuizStep> findByStepOrder(int stepOrder);

    /**
     * 코스 목록 조회(#247) — 여러 코스의 스텝을 한 번에 가져와 코스별로 묶기 좋게 정렬해 반환한다.
     * stepOrder=0(quiz FK 제약을 만족시키기 위한 "(미배정)" sentinel, #257)은 실제 커리큘럼이 아니므로 제외한다.
     */
    @Query("SELECT s FROM QuizStep s WHERE s.courseId IN :courseIds AND s.stepOrder > 0 "
            + "ORDER BY s.courseId ASC, s.stepOrder ASC")
    List<QuizStep> findByCourseIdInOrderByCourseIdAscStepOrderAsc(Collection<Long> courseIds);

    /** 완료한 스텝 이력 조회용 — startInclusive > endInclusive면(완료한 스텝 없음) 빈 목록을 반환한다. */
    List<QuizStep> findByStepOrderBetweenOrderByStepOrderAsc(int startInclusive, int endInclusive);

    /** 지식 그래프 relatedSteps의 topic 조립용 — 흩어진 stepOrder 집합에 대한 일괄 조회(#233). */
    List<QuizStep> findByStepOrderIn(Collection<Integer> stepOrders);

    /**
     * 코스의 "시작 스텝" — stepOrder가 코스와 무관하게 전역 순번이라 코스마다 1이 아닐 수 있다
     * (예: 디자인패턴 코스는 13부터 시작). 진행 기록이 없는 신규 유저의 기본 커서를 정하는 데 쓴다.
     * stepOrder=0(quiz FK 제약을 만족시키기 위한 "(미배정)" sentinel, #257)은 제외한다.
     */
    @Query("SELECT MIN(s.stepOrder) FROM QuizStep s WHERE s.courseId = :courseId AND s.stepOrder > 0")
    Optional<Integer> findMinStepOrderByCourseId(Long courseId);

    /** 코스의 "마지막 스텝" — 홈 화면 커서를 그 코스의 범위 안으로 clamp하는 데 쓴다. */
    @Query("SELECT MAX(s.stepOrder) FROM QuizStep s WHERE s.courseId = :courseId")
    Optional<Integer> findMaxStepOrderByCourseId(Long courseId);

    /** 전체 라이브 스텝 중 가장 큰 순서 — 문제 행이 비어 있는 스텝도 다음 순서 계산에 포함한다. */
    @Query("SELECT MAX(s.stepOrder) FROM QuizStep s")
    Optional<Integer> findMaxStepOrder();
}
