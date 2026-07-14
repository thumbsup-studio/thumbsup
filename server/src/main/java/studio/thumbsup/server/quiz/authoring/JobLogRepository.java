package studio.thumbsup.server.quiz.authoring;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface JobLogRepository extends JpaRepository<JobLog, Long> {

    List<JobLog> findByJobIdAndSeqGreaterThanOrderBySeqAsc(Long jobId, int seq);

    Optional<JobLog> findTopByJobIdOrderBySeqDesc(Long jobId);
}
