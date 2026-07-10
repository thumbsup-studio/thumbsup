package studio.thumbsup.server.quiz;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface QuizStepRepository extends JpaRepository<QuizStep, Long> {

    Optional<QuizStep> findByStepOrder(int stepOrder);

    /**
     * 실제 커리큘럼 스텝 수 — {@code step_order=0}은 스텝 밖 placeholder 샘플의 sentinel이라 제외한다
     * (V20260709201632__create_quiz_step.sql 참조).
     */
    long countByStepOrderGreaterThan(int stepOrder);

    /** 완료한 스텝 이력 조회용 — startInclusive > endInclusive면(완료한 스텝 없음) 빈 목록을 반환한다. */
    List<QuizStep> findByStepOrderBetweenOrderByStepOrderAsc(int startInclusive, int endInclusive);
}
