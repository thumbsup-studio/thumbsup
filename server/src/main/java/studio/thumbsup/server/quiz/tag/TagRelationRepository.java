package studio.thumbsup.server.quiz.tag;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TagRelationRepository extends JpaRepository<TagRelation, Long> {

    /** 그래프 엣지 — 양쪽 태그가 모두 유저의 학습 노드 집합에 있는 관계만 내려주기 위한 조회. */
    List<TagRelation> findBySourceTagIdInAndTargetTagIdIn(Collection<Long> sourceTagIds, Collection<Long> targetTagIds);
}
