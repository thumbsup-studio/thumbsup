package studio.thumbsup.server.quiz.concept;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ConceptRelationRepository extends JpaRepository<ConceptRelation, Long> {

    /** 그래프 엣지 — 양쪽 concept이 모두 유저의 학습 노드 집합에 있는 관계만 내려주기 위한 조회. */
    List<ConceptRelation> findBySourceConceptIdInAndTargetConceptIdIn(
            Collection<Long> sourceConceptIds, Collection<Long> targetConceptIds);
}
