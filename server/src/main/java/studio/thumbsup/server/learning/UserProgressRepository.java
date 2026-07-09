package studio.thumbsup.server.learning;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserProgressRepository extends JpaRepository<UserProgress, Long> {

    /** MVP는 유저당 코스 1개뿐이라 유저 기준으로만 조회한다(코스 여러 개가 되면 courseId도 함께 조건). */
    Optional<UserProgress> findByUserId(Long userId);
}
