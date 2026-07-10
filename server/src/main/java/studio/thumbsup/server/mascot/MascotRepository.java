package studio.thumbsup.server.mascot;

import jakarta.persistence.LockModeType;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface MascotRepository extends JpaRepository<Mascot, Long> {

    Optional<Mascot> findByUserId(Long userId);

    /** feed() 동시 호출 레이스를 막기 위한 비관적 락 조회 — quiz.QuizProgressRepository와 동일 패턴. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT m FROM Mascot m WHERE m.userId = :userId")
    Optional<Mascot> findByUserIdForUpdate(Long userId);
}
