package studio.thumbsup.server.quiz.concept;

import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserConceptRepository extends JpaRepository<UserConcept, Long> {

    /** 지식 그래프 조회 — 유저가 학습한 모든 개념(learnedAt 포함). */
    List<UserConcept> findByUserId(Long userId);

    /** 스텝 완료 시 이미 기록된 개념인지 확인해 중복 INSERT를 피하기 위한 조회. */
    List<UserConcept> findByUserIdAndConceptIdIn(Long userId, Collection<Long> conceptIds);
}
