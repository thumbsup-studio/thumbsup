package studio.thumbsup.server.quiz;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface QuizAttemptRepository extends JpaRepository<QuizAttempt, Long> {

    /** 특정 스텝에서 이 유저가 이미 푼 시도 목록 — "다음 문제" 계산에 쓰인다. */
    List<QuizAttempt> findByUserIdAndQuiz_StepOrder(Long userId, int stepOrder);

    /**
     * 풀이 기록(#261) 첫 페이지 — 유저의 시도를 최신순으로. {@code quiz}는 다대일이라 fetch join해도
     * 행이 늘지 않아 페이지네이션과 안전하게 같이 쓸 수 있다(선택지 등 하위 컬렉션은 조인하지 않는다 —
     * 컬렉션 fetch join은 LIMIT과 함께 쓰면 Hibernate가 메모리 페이징으로 빠진다).
     */
    @Query("SELECT a FROM QuizAttempt a JOIN FETCH a.quiz WHERE a.userId = :userId ORDER BY a.id DESC")
    List<QuizAttempt> findPageByUserId(@Param("userId") Long userId, Pageable pageable);

    /** 풀이 기록(#261) 다음 페이지 — 커서(마지막으로 본 id) 미만을 이어서 조회. */
    @Query("SELECT a FROM QuizAttempt a JOIN FETCH a.quiz "
            + "WHERE a.userId = :userId AND a.id < :cursorId ORDER BY a.id DESC")
    List<QuizAttempt> findPageByUserIdBeforeId(
            @Param("userId") Long userId, @Param("cursorId") Long cursorId, Pageable pageable);
}
