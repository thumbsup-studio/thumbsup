package studio.thumbsup.server.quiz;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface QuizStepRepository extends JpaRepository<QuizStep, Long> {

    Optional<QuizStep> findByStepOrder(int stepOrder);
}
