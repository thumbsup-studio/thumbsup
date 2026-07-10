package studio.thumbsup.server.quiz;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface QuizRepository extends JpaRepository<Quiz, Long> {

    /** 한 스텝(5문제)을 출제 순서대로 조회한다. */
    List<Quiz> findByStepOrderOrderBySlotOrderAsc(int stepOrder);

    /** 스텝·슬롯 지정 조회(#151) — 재풀이용이라 시도 여부와 무관하게 그 자리 문제를 그대로 준다. */
    Optional<Quiz> findByStepOrderAndSlotOrder(int stepOrder, int slotOrder);

    /** 해설 화면의 진행 표시를 위해 해당 스텝에 실제 저장된 문제 수를 센다. */
    long countByStepOrder(int stepOrder);

    /** 스텝 완료 여부 판정처럼 ID만 필요할 때 — TEXT 컬럼이 큰 본문을 불필요하게 읽지 않는다. */
    @Query("SELECT q.id FROM Quiz q WHERE q.stepOrder = :stepOrder")
    List<Long> findIdsByStepOrder(int stepOrder);

    /**
     * 정식 커리큘럼(step_order > 0)의 최댓값 — 다음 생성분의 스텝 번호 계산에 쓰인다(#26).
     * 0은 "스텝 밖" placeholder 샘플 데이터를 가리키는 sentinel이라 제외한다.
     */
    @Query("SELECT MAX(q.stepOrder) FROM Quiz q WHERE q.stepOrder > 0")
    Optional<Integer> findMaxStepOrder();
}
