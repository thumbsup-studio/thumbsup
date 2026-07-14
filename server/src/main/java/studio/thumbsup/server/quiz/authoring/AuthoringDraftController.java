package studio.thumbsup.server.quiz.authoring;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.quiz.authoring.dto.ApproveResponse;
import studio.thumbsup.server.quiz.authoring.dto.DraftDetailResponse;
import studio.thumbsup.server.quiz.authoring.dto.DraftListResponse;
import studio.thumbsup.server.quiz.authoring.dto.GenerateRequest;
import studio.thumbsup.server.quiz.authoring.dto.JobCreatedResponse;
import studio.thumbsup.server.quiz.authoring.dto.ReviewRequest;

/**
 * 컨트롤러는 얇게 — 검증(어노테이션)·호출·envelope 감싸기만 한다.
 * 엔티티는 만질 수 없다(ArchUnit 강제) — DTO 변환은 Service에서 끝난다.
 */
@Tag(name = "Authoring Draft", description = "문제 저작 draft — 생성·검수·승인·조회")
@RestController
@RequestMapping("/api/v1/authoring/drafts")
public class AuthoringDraftController {

    private final AuthoringJobService jobService;
    private final AuthoringDraftService draftService;
    private final AuthoringApprovalService approvalService;

    public AuthoringDraftController(
            AuthoringJobService jobService,
            AuthoringDraftService draftService,
            AuthoringApprovalService approvalService) {
        this.jobService = jobService;
        this.draftService = draftService;
        this.approvalService = approvalService;
    }

    @Operation(summary = "새 문제 세트 생성 잡을 큐에 넣는다")
    @ResponseStatus(HttpStatus.ACCEPTED)
    @PostMapping("/generate")
    public ApiResponse<JobCreatedResponse> generate(
            @AuthenticationPrincipal Long userId, @Valid @RequestBody GenerateRequest request) {
        return ApiResponse.success(new JobCreatedResponse(jobService.enqueueGenerate(userId, request.topic())));
    }

    @Operation(summary = "draft 검수(재생성) 잡을 큐에 넣는다")
    @ResponseStatus(HttpStatus.ACCEPTED)
    @PostMapping("/{draftId}/reviews")
    public ApiResponse<JobCreatedResponse> review(
            @AuthenticationPrincipal Long userId,
            @PathVariable Long draftId,
            @Valid @RequestBody ReviewRequest request) {
        return ApiResponse.success(
                new JobCreatedResponse(jobService.enqueueReview(userId, draftId, request.feedback())));
    }

    @Operation(summary = "draft를 승인해 라이브 문제로 반영한다")
    @PostMapping("/{draftId}/approve")
    public ApiResponse<ApproveResponse> approve(@AuthenticationPrincipal Long userId, @PathVariable Long draftId) {
        return ApiResponse.success(approvalService.approveForResponse(userId, draftId));
    }

    @Operation(summary = "draft 목록 조회")
    @GetMapping
    public ApiResponse<DraftListResponse> list(@RequestParam QuizDraftStatus status) {
        return ApiResponse.success(draftService.listSummaries(status));
    }

    @Operation(summary = "draft 상세 조회")
    @GetMapping("/{draftId}")
    public ApiResponse<DraftDetailResponse> detail(@PathVariable Long draftId) {
        return ApiResponse.success(draftService.getDetail(draftId));
    }
}
