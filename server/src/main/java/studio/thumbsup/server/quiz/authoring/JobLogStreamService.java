package studio.thumbsup.server.quiz.authoring;

import java.io.IOException;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/**
 * 잡 실행 로그의 SSE 팬아웃(#174 T9) — 잡 하나당 구독 중인 emitter를 인메모리로 들고 있다가
 * {@link #broadcast}/{@link #notifyStatus}가 호출되면 그 잡을 구독 중인 전원에게 이벤트를 쏜다.
 *
 * <p>⚠️ 단일 인스턴스 전제 — 현재 배포는 EC2 컨테이너 1대(host 네트워크, 오토스케일 없음)라 이 인메모리
 * 레지스트리로 충분하다. 인스턴스를 2대 이상으로 늘리면 브리지가 결과를 제출한 인스턴스와 구독자가 붙어
 * 있는 인스턴스가 달라질 수 있어 이 방식이 깨진다 — 그때는 Redis pub/sub 등 외부 브로커로 교체해야 한다.
 *
 * <p>{@code @Service}가 아니라 {@code @Component}다 — SSE emitter로의 전송은 I/O이지 DB 트랜잭션이
 * 아니라서 {@code @Transactional} 경계 안에 있을 이유가 없다(ArchUnit도 {@code @Transactional}을
 * Service 계층에만 허용한다). 대신 {@link AuthoringJobService}·{@link JobLogService}가 가진
 * 트랜잭션 완료 후의 조회 메서드를 그대로 재사용한다.
 */
@Component
public class JobLogStreamService {

    private static final long EMITTER_TIMEOUT_MS = Duration.ofMinutes(30).toMillis();

    private final ConcurrentHashMap<Long, CopyOnWriteArrayList<SseEmitter>> emittersByJobId = new ConcurrentHashMap<>();
    private final AuthoringJobService jobService;
    private final JobLogService jobLogService;

    public JobLogStreamService(AuthoringJobService jobService, JobLogService jobLogService) {
        this.jobService = jobService;
        this.jobLogService = jobLogService;
    }

    /** 구독 시작 — {@code fromSeq} 이후 로그를 리플레이하고, 이미 종결된 잡이면 status 이벤트 후 즉시 종료한다. */
    public SseEmitter subscribe(Long jobId, Integer fromSeq) {
        GenerationJob job = jobService.getJobWithExpiry(jobId); // 없으면 404, 만료 평가도 여기서 함께 끝난다
        SseEmitter emitter = new SseEmitter(EMITTER_TIMEOUT_MS);

        List<JobLog> backlog = jobLogService.after(jobId, fromSeq == null ? 0 : fromSeq);
        try {
            for (JobLog log : backlog) {
                emitter.send(logEvent(log));
            }
        } catch (IOException e) {
            emitter.completeWithError(e);
            return emitter;
        }

        if (!job.isActive()) {
            sendTerminalStatusAndComplete(emitter, job);
            return emitter;
        }

        register(jobId, emitter);
        return emitter;
    }

    /** 브리지가 로그를 적재한 직후 호출 — 그 잡을 구독 중인 emitter 전원에게 새로 쌓인 줄만 전달한다. */
    public void broadcast(Long jobId, List<JobLog> lines) {
        CopyOnWriteArrayList<SseEmitter> subscribers = emittersByJobId.get(jobId);
        if (subscribers == null || lines.isEmpty()) {
            return;
        }
        for (SseEmitter emitter : subscribers) {
            for (JobLog log : lines) {
                if (!trySend(emitter, logEvent(log))) {
                    remove(jobId, emitter);
                    break;
                }
            }
        }
    }

    /** 잡이 SUCCEEDED/FAILED로 종결된 직후 호출 — status 이벤트를 보내고 구독을 전부 끝맺는다. */
    public void notifyStatus(Long jobId, String status, Long draftId, String error) {
        notifyStatus(jobId, status, draftId, error, null);
    }

    /** 종료 상태에 뼈대 참조를 함께 보낸다 — 기존 호출자 호환을 위해 기존 overload도 유지한다. */
    public void notifyStatus(Long jobId, String status, Long draftId, String error, Long outlineId) {
        List<SseEmitter> subscribers = emittersByJobId.remove(jobId);
        if (subscribers == null) {
            return;
        }
        SseEmitter.SseEventBuilder event = statusEvent(status, draftId, error, outlineId);
        for (SseEmitter emitter : subscribers) {
            if (trySend(emitter, event)) {
                emitter.complete();
            }
        }
    }

    private void sendTerminalStatusAndComplete(SseEmitter emitter, GenerationJob job) {
        SseEmitter.SseEventBuilder event =
                statusEvent(job.getStatus().name(), job.getDraftId(), job.getError(), job.getOutlineId());
        if (trySend(emitter, event)) {
            emitter.complete();
        }
    }

    private void register(Long jobId, SseEmitter emitter) {
        emittersByJobId
                .computeIfAbsent(jobId, key -> new CopyOnWriteArrayList<>())
                .add(emitter);
        emitter.onCompletion(() -> remove(jobId, emitter));
        emitter.onTimeout(() -> remove(jobId, emitter));
        emitter.onError(e -> remove(jobId, emitter));
    }

    private void remove(Long jobId, SseEmitter emitter) {
        CopyOnWriteArrayList<SseEmitter> subscribers = emittersByJobId.get(jobId);
        if (subscribers != null && subscribers.remove(emitter) && subscribers.isEmpty()) {
            emittersByJobId.remove(jobId, subscribers);
        }
    }

    /** 전송 성공 여부만 돌려준다 — IOException이 나는 emitter는 여기서 completeWithError로 끝맺는다. */
    private boolean trySend(SseEmitter emitter, SseEmitter.SseEventBuilder event) {
        try {
            emitter.send(event);
            return true;
        } catch (IOException e) {
            emitter.completeWithError(e);
            return false;
        }
    }

    private SseEmitter.SseEventBuilder logEvent(JobLog log) {
        return SseEmitter.event()
                .id(String.valueOf(log.getSeq()))
                .name("log")
                .data(new LogEventPayload(log.getSeq(), log.getLine()), MediaType.APPLICATION_JSON);
    }

    private SseEmitter.SseEventBuilder statusEvent(String status, Long draftId, String error, Long outlineId) {
        return SseEmitter.event()
                .name("status")
                .data(new StatusEventPayload(status, draftId, error, outlineId), MediaType.APPLICATION_JSON);
    }

    private record LogEventPayload(int seq, String line) {}

    private record StatusEventPayload(String status, Long draftId, String error, Long outlineId) {}
}
