package studio.thumbsup.server.quiz;

import jakarta.persistence.LockModeType;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface QuizProgressRepository extends JpaRepository<QuizProgress, Long> {

    Optional<QuizProgress> findByUserIdAndCourseId(Long userId, Long courseId);

    /** 코스 목록 조회(#247) — 유저의 여러 코스 진행 커서를 한 번에 가져와 N+1을 피한다. */
    List<QuizProgress> findByUserIdAndCourseIdIn(Long userId, Collection<Long> courseIds);

    /**
     * 스텝 완료 판정·진행 갱신 구간을 유저·코스 단위로 직렬화하기 위한 비관적 락 조회.
     * {@link QuizService}의 동시 정답 제출 레이스를 막는 데 쓰인다.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT p FROM QuizProgress p WHERE p.userId = :userId AND p.courseId = :courseId")
    Optional<QuizProgress> findByUserIdAndCourseIdForUpdate(Long userId, Long courseId);
}
