package studio.thumbsup.server.quiz.authoring;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.quiz.authoring.dto.JobStatusResponse;

/**
 * 컨트롤러는 얇게 — 검증(어노테이션)·호출·envelope 감싸기만 한다.
 * 엔티티는 만질 수 없다(ArchUnit 강제) — DTO 변환은 Service에서 끝난다.
 *
 * <p>스트림(SSE, #174 T9)은 엔벨로프({@code ApiResponse})를 씌우지 않는다 — {@code SseEmitter}를 그대로 반환한다.
 */
@Tag(name = "Authoring Job", description = "저작 잡 상태 조회·로그 스트림")
@RestController
@RequestMapping("/api/v1/authoring/jobs")
public class AuthoringJobController {

    private final AuthoringJobService jobService;
    private final JobLogStreamService jobLogStreamService;

    public AuthoringJobController(AuthoringJobService jobService, JobLogStreamService jobLogStreamService) {
        this.jobService = jobService;
        this.jobLogStreamService = jobLogStreamService;
    }

    @Operation(summary = "잡 상태 조회 — 팀원 누구나 조회 가능(assignee 제한 없음)")
    @GetMapping("/{jobId}")
    public ApiResponse<JobStatusResponse> getJob(@PathVariable Long jobId) {
        return ApiResponse.success(jobService.getJobStatus(jobId));
    }

    @Operation(summary = "잡 실행 로그를 SSE로 구독한다 — fromSeq 이후 로그를 리플레이한 뒤 실시간으로 이어받는다")
    @GetMapping("/{jobId}/stream")
    public SseEmitter stream(
            @PathVariable Long jobId, @RequestParam(required = false) Integer fromSeq, HttpServletResponse response) {
        // Nginx가 SSE 응답을 버퍼링하면 이벤트가 실시간으로 전달되지 않는다 — 프록시 버퍼링을 끈다.
        response.setHeader("X-Accel-Buffering", "no");
        return jobLogStreamService.subscribe(jobId, fromSeq);
    }
}
