package studio.thumbsup.server.quiz.tag;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface QuizTagRepository extends JpaRepository<QuizTag, Long> {

    /** 스텝 완료 시 학습한 것으로 기록할 태그 id 목록. */
    @Query("SELECT DISTINCT qt.tagId FROM QuizTag qt WHERE qt.quizId IN :quizIds")
    List<Long> findDistinctTagIdsByQuizIdIn(Collection<Long> quizIds);
}
