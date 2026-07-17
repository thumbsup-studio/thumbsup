package studio.thumbsup.server.quiz.authoring;

import java.util.ArrayList;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 잡 실행 로그(#174 T8) 적재·조회 — SSE 스트림 재연결({@code fromSeq})이 이어받을 지점을 결정적으로
 * 계산할 수 있도록, seq는 항상 마지막 seq+1부터 요청 안의 라인 순서대로 연속 부여한다.
 */
@Service
public class JobLogService {

    private final JobLogRepository jobLogRepository;

    public JobLogService(JobLogRepository jobLogRepository) {
        this.jobLogRepository = jobLogRepository;
    }

    @Transactional
    public List<JobLog> append(Long jobId, List<String> lines) {
        int nextSeq = jobLogRepository
                .findTopByJobIdOrderBySeqDesc(jobId)
                .map(log -> log.getSeq() + 1)
                .orElse(1);

        List<JobLog> logs = new ArrayList<>(lines.size());
        for (String line : lines) {
            logs.add(JobLog.create(jobId, nextSeq++, line));
        }
        return jobLogRepository.saveAll(logs);
    }

    @Transactional(readOnly = true)
    public List<JobLog> after(Long jobId, int fromSeq) {
        return jobLogRepository.findByJobIdAndSeqGreaterThanOrderBySeqAsc(jobId, fromSeq);
    }
}
