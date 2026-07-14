package studio.thumbsup.server.quiz.authoring;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface QuizDraftRepository extends JpaRepository<QuizDraft, Long> {

    List<QuizDraft> findByStatusOrderByUpdatedAtDesc(QuizDraftStatus status);

    boolean existsBySourceQuizIdAndStatus(Long sourceQuizId, QuizDraftStatus status);
}
