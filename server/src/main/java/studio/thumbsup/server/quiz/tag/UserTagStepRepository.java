package studio.thumbsup.server.quiz.tag;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserTagStepRepository extends JpaRepository<UserTagStep, Long> {

    /** 지식 그래프 상세 카드의 relatedSteps 조립용 — 유저가 학습한 태그들의 관련 완료 스텝 전체. */
    List<UserTagStep> findByUserIdAndTagIdIn(Long userId, Collection<Long> tagIds);
}
