package studio.thumbsup.server.quiz.authoring;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/**
 * 잡 실행 중 브리지가 보내는 로그 한 줄 — {@code (jobId, seq)}가 unique라 SSE 스트림 재연결 시
 * {@code fromSeq}로 이어받을 지점을 결정적으로 계산할 수 있다.
 */
@Getter
@Entity
@Table(name = "job_log")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class JobLog extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long jobId;

    @Column(nullable = false)
    private int seq;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String line;

    private JobLog(Long jobId, int seq, String line) {
        this.jobId = jobId;
        this.seq = seq;
        this.line = line;
    }

    public static JobLog create(Long jobId, int seq, String line) {
        return new JobLog(jobId, seq, line);
    }
}
