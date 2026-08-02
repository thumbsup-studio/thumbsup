package studio.thumbsup.server.quiz.concept;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserConceptStepRepository extends JpaRepository<UserConceptStep, Long> {

    /** 지식 그래프 상세 카드의 relatedSteps 조립용 — 유저가 학습한 개념들의 관련 완료 스텝 전체. */
    List<UserConceptStep> findByUserIdAndConceptIdIn(Long userId, Collection<Long> conceptIds);
}
