package studio.thumbsup.server.quiz.authoring;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface QuizDraftRevisionRepository extends JpaRepository<QuizDraftRevision, Long> {

    List<QuizDraftRevision> findByDraftIdOrderByRevisionNoDesc(Long draftId);

    Optional<QuizDraftRevision> findTopByDraftIdOrderByRevisionNoDesc(Long draftId);
}
