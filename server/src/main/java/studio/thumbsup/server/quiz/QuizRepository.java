package studio.thumbsup.server.quiz;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface QuizRepository extends JpaRepository<Quiz, Long> {

    /** 한 스텝(5문제)을 출제 순서대로 조회한다. */
    List<Quiz> findByStepOrderOrderBySlotOrderAsc(int stepOrder);
}
