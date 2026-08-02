package studio.thumbsup.server.quiz.authoring;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AuthoringOutlineStepRepository extends JpaRepository<AuthoringOutlineStep, Long> {

    List<AuthoringOutlineStep> findByOutlineIdOrderByOrderNoAsc(Long outlineId);

    List<AuthoringOutlineStep> findByOutlineIdInOrderByOutlineIdAscOrderNoAsc(Collection<Long> outlineIds);

    Optional<AuthoringOutlineStep> findByOutlineIdAndOrderNo(Long outlineId, int orderNo);

    boolean existsByOutlineIdAndDraftIdIsNotNull(Long outlineId);

    void deleteByOutlineId(Long outlineId);

    Optional<AuthoringOutlineStep> findByDraftId(Long draftId);
}
