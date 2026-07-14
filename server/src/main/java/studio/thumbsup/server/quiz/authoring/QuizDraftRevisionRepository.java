package studio.thumbsup.server.quiz.authoring;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface QuizDraftRevisionRepository extends JpaRepository<QuizDraftRevision, Long> {

    List<QuizDraftRevision> findByDraftIdOrderByRevisionNoDesc(Long draftId);

    Optional<QuizDraftRevision> findTopByDraftIdOrderByRevisionNoDesc(Long draftId);

    /** draft 목록(#174 T7)의 revisionCount — 목록 전체를 안 불러오고 카운트만 센다. */
    long countByDraftId(Long draftId);
}
