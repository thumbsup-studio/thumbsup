package studio.thumbsup.server.quiz.authoring;

import jakarta.persistence.LockModeType;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface QuizDraftRepository extends JpaRepository<QuizDraft, Long> {

    List<QuizDraft> findByStatusOrderByUpdatedAtDesc(QuizDraftStatus status);

    List<QuizDraft> findByIdIn(Collection<Long> ids);

    boolean existsBySourceQuizIdAndStatus(Long sourceQuizId, QuizDraftStatus status);

    /**
     * 승인·검수 재요청처럼 같은 draft에 대한 동시 write를 직렬화해야 하는 진입점 전용(#174 I2) —
     * {@code approve}/{@code enqueueReview}의 check-then-act(상태·활성잡 가드) race를 막는다.
     * 반드시 쓰기 트랜잭션 안에서 호출해야 한다(readOnly면 MySQL이 FOR UPDATE를 거부한다).
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT d FROM QuizDraft d WHERE d.id = :id")
    Optional<QuizDraft> findByIdForUpdate(@Param("id") Long id);
}
