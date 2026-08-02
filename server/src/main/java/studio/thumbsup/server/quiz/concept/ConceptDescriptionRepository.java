package studio.thumbsup.server.quiz.concept;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ConceptDescriptionRepository extends JpaRepository<ConceptDescription, Long> {

    /** 지식 그래프 노드의 description 조립용 — 유저가 학습한 개념들의 스텝별 설명 문장 전체. */
    List<ConceptDescription> findByConceptIdIn(Collection<Long> conceptIds);
}
