package studio.thumbsup.server.quiz.tag;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TagDescriptionRepository extends JpaRepository<TagDescription, Long> {

    /** 지식 그래프 노드의 description 조립용 — 유저가 학습한 태그들의 스텝별 설명 문장 전체. */
    List<TagDescription> findByTagIdIn(Collection<Long> tagIds);
}
