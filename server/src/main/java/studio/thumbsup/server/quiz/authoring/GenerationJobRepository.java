package studio.thumbsup.server.quiz.authoring;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface GenerationJobRepository extends JpaRepository<GenerationJob, Long> {

    /**
     * 본인 소유 QUEUED 잡을 하나 집어 잠근다. {@code SKIP LOCKED}는 이 메서드가 반환하는 순간이 아니라
     * 트랜잭션이 끝날 때 풀린다 — 호출자가 pick 직후의 상태 변경(예: {@link GenerationJob#markRunning})과
     * 저장을 같은 {@code @Transactional} 경계 안에서 처리해야 락이 유지되어 동시 폴링과 경합하지 않는다.
     * 트랜잭션 없이 단독 호출하면 커밋 즉시 락이 풀려 중복 pick이 발생할 수 있다.
     */
    @Query(
            value = "SELECT * FROM generation_job WHERE status = 'QUEUED' AND assignee_user_id = :userId "
                    + "ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED",
            nativeQuery = true)
    Optional<GenerationJob> pickNextQueued(@Param("userId") Long userId);

    List<GenerationJob> findByDraftIdAndStatusIn(Long draftId, Collection<GenerationJobStatus> statuses);

    List<GenerationJob> findByOutlineStepIdInAndStatusIn(
            Collection<Long> outlineStepIds, Collection<GenerationJobStatus> statuses);

    List<GenerationJob> findByOutlineStepIdAndStatusIn(Long outlineStepId, Collection<GenerationJobStatus> statuses);

    List<GenerationJob> findByOutlineIdAndStatusIn(Long outlineId, Collection<GenerationJobStatus> statuses);
}
