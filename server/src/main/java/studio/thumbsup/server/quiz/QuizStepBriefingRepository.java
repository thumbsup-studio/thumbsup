package studio.thumbsup.server.quiz;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface QuizStepBriefingRepository extends JpaRepository<QuizStepBriefing, Long> {

    @Query("SELECT briefing FROM QuizStepBriefing briefing "
            + "LEFT JOIN FETCH briefing.blocks "
            + "WHERE briefing.quizStepId = :quizStepId")
    Optional<QuizStepBriefing> findWithBlocksByQuizStepId(@Param("quizStepId") Long quizStepId);
}
