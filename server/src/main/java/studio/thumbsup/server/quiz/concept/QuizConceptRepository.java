package studio.thumbsup.server.quiz.concept;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface QuizConceptRepository extends JpaRepository<QuizConcept, Long> {

    /** 스텝 완료 시 학습한 것으로 기록할 개념 id 목록. */
    @Query("SELECT DISTINCT qc.conceptId FROM QuizConcept qc WHERE qc.quizId IN :quizIds")
    List<Long> findDistinctConceptIdsByQuizIdIn(Collection<Long> quizIds);
}
