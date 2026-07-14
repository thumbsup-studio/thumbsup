package studio.thumbsup.server.quiz.authoring;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.quiz.authoring.dto.JobStatusResponse;

/**
 * 컨트롤러는 얇게 — 검증(어노테이션)·호출·envelope 감싸기만 한다.
 * 엔티티는 만질 수 없다(ArchUnit 강제) — DTO 변환은 Service에서 끝난다.
 *
 * <p>스트림(SSE) 엔드포인트는 T9에서 별도 컨트롤러로 추가한다.
 */
@Tag(name = "Authoring Job", description = "저작 잡 상태 조회")
@RestController
@RequestMapping("/api/v1/authoring/jobs")
public class AuthoringJobController {

    private final AuthoringJobService jobService;

    public AuthoringJobController(AuthoringJobService jobService) {
        this.jobService = jobService;
    }

    @Operation(summary = "잡 상태 조회 — 팀원 누구나 조회 가능(assignee 제한 없음)")
    @GetMapping("/{jobId}")
    public ApiResponse<JobStatusResponse> getJob(@PathVariable Long jobId) {
        return ApiResponse.success(jobService.getJobStatus(jobId));
    }
}
