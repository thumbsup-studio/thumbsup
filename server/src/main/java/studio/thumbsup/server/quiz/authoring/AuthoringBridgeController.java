package studio.thumbsup.server.quiz.authoring;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.quiz.authoring.dto.BridgeFailRequest;
import studio.thumbsup.server.quiz.authoring.dto.BridgeJobResponse;
import studio.thumbsup.server.quiz.authoring.dto.BridgeLogsRequest;
import studio.thumbsup.server.quiz.authoring.dto.BridgeResultRequest;
import studio.thumbsup.server.quiz.authoring.dto.BridgeResultResponse;
import studio.thumbsup.server.quiz.authoring.dto.JobStatusResponse;

/**
 * 로컬 브리지가 폴링·실행 결과를 보고하는 엔드포인트(#174 T8~T9) — 대시보드 컨트롤러와 마찬가지로
 * 엔티티는 만질 수 없다(ArchUnit 강제).
 *
 * <p>logs 적재·result/fail 제출이 성공한 직후 이 컨트롤러가 {@code JobLogStreamService}에
 * broadcast/notifyStatus를 위임한다(#174 T9) — {@code AuthoringJobService.submitResultForBridge} 안에서
 * 바로 호출하지 않는 이유: 그 메서드는 이미 파라미터 7개로 checkstyle {@code ParameterNumber} 상한이라
 * {@code JobLogStreamService}를 더 주입할 여지가 없고, SSE emitter로의 전송(I/O)을 DB
 * {@code @Transactional} 경계 안에 두고 싶지 않다 — 트랜잭션이 커밋된 뒤(컨트롤러 시점)에 쏘는 편이 맞다.
 */
@Tag(name = "Authoring Bridge", description = "로컬 브리지 폴링·로그·결과 제출")
@RestController
@RequestMapping("/api/v1/authoring/bridge")
public class AuthoringBridgeController {

    private final AuthoringJobService jobService;
    private final JobLogService jobLogService;
    private final JobLogStreamService jobLogStreamService;

    public AuthoringBridgeController(
            AuthoringJobService jobService, JobLogService jobLogService, JobLogStreamService jobLogStreamService) {
        this.jobService = jobService;
        this.jobLogService = jobLogService;
        this.jobLogStreamService = jobLogStreamService;
    }

    @Operation(summary = "다음 잡을 폴링해 집는다 — 없으면 data:null")
    @GetMapping("/jobs/next")
    public ApiResponse<BridgeJobResponse> next(@AuthenticationPrincipal Long userId) {
        return ApiResponse.success(jobService.claimNextForBridge(userId).orElse(null));
    }

    @Operation(summary = "실행 로그를 적재한다 — RUNNING 잡이 아니면 조용히 건너뛴다")
    @PostMapping("/jobs/{jobId}/logs")
    public ApiResponse<Void> logs(
            @AuthenticationPrincipal Long userId,
            @PathVariable Long jobId,
            @Valid @RequestBody BridgeLogsRequest request) {
        if (jobService.canAppendLogs(userId, jobId)) {
            jobLogStreamService.broadcast(jobId, jobLogService.append(jobId, request.lines()));
        }
        return ApiResponse.success(null);
    }

    @Operation(summary = "실행 결과를 제출한다 — 검증 실패로 FAILED가 되어도 200이다")
    @PostMapping("/jobs/{jobId}/result")
    public ApiResponse<BridgeResultResponse> result(
            @AuthenticationPrincipal Long userId,
            @PathVariable Long jobId,
            @Valid @RequestBody BridgeResultRequest request) {
        BridgeResultResponse response =
                jobService.submitResultForBridge(userId, jobId, request.cli(), request.resultJson());
        notifyStreamStatus(jobId);
        return ApiResponse.success(response);
    }

    @Operation(summary = "실행 자체가 실패했음을 보고한다")
    @PostMapping("/jobs/{jobId}/fail")
    public ApiResponse<Void> fail(
            @AuthenticationPrincipal Long userId,
            @PathVariable Long jobId,
            @Valid @RequestBody BridgeFailRequest request) {
        jobService.failJobForBridge(userId, jobId, request.error());
        notifyStreamStatus(jobId);
        return ApiResponse.success(null);
    }

    /** result/fail 둘 다 종결 후 최신 상태를 다시 읽어 SSE status 이벤트로 흘려보낸다. */
    private void notifyStreamStatus(Long jobId) {
        JobStatusResponse status = jobService.getJobStatus(jobId);
        jobLogStreamService.notifyStatus(jobId, status.status(), status.draftId(), status.error());
    }
}
