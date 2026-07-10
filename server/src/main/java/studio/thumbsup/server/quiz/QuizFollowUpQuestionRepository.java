package studio.thumbsup.server.quiz;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface QuizFollowUpQuestionRepository extends JpaRepository<QuizFollowUpQuestion, Long> {

    /**
     * 출처 문제를 함께 읽는다 — 응답의 {@code sourceQuizNumber}가 부모 문제의 slotOrder이기 때문이다.
     * 블록·키워드는 각각 별도 컬렉션이라 함께 fetch join하면 MultipleBagFetchException이 난다.
     * 단건 조회라 지연 로딩 두 번으로 충분하다.
     */
    @Query("select f from QuizFollowUpQuestion f join fetch f.quiz where f.id = :followUpQuestionId")
    Optional<QuizFollowUpQuestion> findWithQuizById(Long followUpQuestionId);
}
