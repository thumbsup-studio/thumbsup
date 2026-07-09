package studio.thumbsup.server.learning;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UnitRepository extends JpaRepository<Unit, Long> {

    /** 코스 내 특정 순번의 화 — "현재/다음 화" 조회에 쓰인다. */
    Optional<Unit> findByCourseIdAndOrderIndex(Long courseId, int orderIndex);

    /** 코스 전체 화 수 — 진행도("n/총화수") 산출에 쓰인다. */
    long countByCourseId(Long courseId);
}
