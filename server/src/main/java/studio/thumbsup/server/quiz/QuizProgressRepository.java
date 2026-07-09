package studio.thumbsup.server.quiz;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface QuizProgressRepository extends JpaRepository<QuizProgress, Long> {

    Optional<QuizProgress> findByUserId(Long userId);
}
