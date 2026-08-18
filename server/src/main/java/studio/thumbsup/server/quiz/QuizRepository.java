package studio.thumbsup.server.quiz;

import jakarta.persistence.LockModeType;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface QuizRepository extends JpaRepository<Quiz, Long> {

    /** 한 스텝(5문제)을 출제 순서대로 조회한다. */
    List<Quiz> findByQuizStepIdOrderBySlotOrderAsc(Long quizStepId);

    /** 스텝·슬롯 지정 조회(#151) — 재풀이용이라 시도 여부와 무관하게 그 자리 문제를 그대로 준다. */
    Optional<Quiz> findByQuizStepIdAndSlotOrder(Long quizStepId, int slotOrder);

    /** 여러 스텝의 문제를 한 번에 조회한다 — 저작 대시보드처럼 코스 전체를 훑는 조회용(#292). */
    List<Quiz> findByQuizStepIdIn(Collection<Long> quizStepIds);

    /** 해설 화면의 진행 표시를 위해 해당 스텝에 실제 저장된 문제 수를 센다. */
    long countByQuizStepId(Long quizStepId);

    /** 스텝 완료 여부 판정처럼 ID만 필요할 때 — TEXT 컬럼이 큰 본문을 불필요하게 읽지 않는다. */
    @Query("SELECT q.id FROM Quiz q WHERE q.quizStepId = :quizStepId")
    List<Long> findIdsByQuizStepId(Long quizStepId);

    /** choices를 즉시 로딩해 조회한다 — 세션이 끝난 뒤에도 지연 로딩 예외 없이 확인해야 하는 호출자용(#174). */
    @Query("SELECT q FROM Quiz q LEFT JOIN FETCH q.choices WHERE q.id = :id")
    Optional<Quiz> findWithChoicesById(Long id);

    /**
     * 같은 문제에 대한 동시 개선 요청을 직렬화하는 전용 조회(#174 I2) — {@code enqueueImprove}의
     * hasOpenImproveDraft check-then-act race(중복 improve draft 생성)를 막는다. 아직 draft가 없는
     * 시점부터 잠가야 하므로 draft가 아니라 원본 quiz 행을 잠근다. 쓰기 트랜잭션 안에서만 호출한다.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT q FROM Quiz q WHERE q.id = :id")
    Optional<Quiz> findByIdForUpdate(@Param("id") Long id);
}
