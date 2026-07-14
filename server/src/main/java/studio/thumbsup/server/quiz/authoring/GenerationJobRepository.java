package studio.thumbsup.server.quiz.authoring;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface GenerationJobRepository extends JpaRepository<GenerationJob, Long> {

    /** 본인 소유 QUEUED 잡을 하나 집어 잠근다 — 다른 브리지 인스턴스의 동시 폴링과 경합하지 않는다. */
    @Query(
            value = "SELECT * FROM generation_job WHERE status = 'QUEUED' AND assignee_user_id = :userId "
                    + "ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED",
            nativeQuery = true)
    Optional<GenerationJob> pickNextQueued(@Param("userId") Long userId);

    List<GenerationJob> findByDraftIdAndStatusIn(Long draftId, Collection<GenerationJobStatus> statuses);
}
