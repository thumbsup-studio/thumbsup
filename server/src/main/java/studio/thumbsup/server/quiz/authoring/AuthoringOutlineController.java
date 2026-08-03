package studio.thumbsup.server.quiz.authoring;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.quiz.authoring.dto.CreateOutlineRequest;
import studio.thumbsup.server.quiz.authoring.dto.CreateOutlineStepRequest;
import studio.thumbsup.server.quiz.authoring.dto.JobCreatedResponse;
import studio.thumbsup.server.quiz.authoring.dto.OutlineCreatedResponse;
import studio.thumbsup.server.quiz.authoring.dto.OutlineDetailResponse;
import studio.thumbsup.server.quiz.authoring.dto.OutlineListResponse;
import studio.thumbsup.server.quiz.authoring.dto.PublishResponse;
import studio.thumbsup.server.quiz.authoring.dto.StepCreatedResponse;
import studio.thumbsup.server.quiz.authoring.dto.UpdateOutlineRequest;

@Tag(name = "Authoring Outline", description = "저작 코스 뼈대 조회·편집")
@RestController
@RequestMapping("/api/v1/authoring/outlines")
public class AuthoringOutlineController {

    private final AuthoringOutlineService outlineService;
    private final AuthoringPublishService publishService;

    public AuthoringOutlineController(AuthoringOutlineService outlineService, AuthoringPublishService publishService) {
        this.outlineService = outlineService;
        this.publishService = publishService;
    }

    @Operation(summary = "뼈대를 생성하고 목차 변환 잡을 큐에 넣는다")
    @ResponseStatus(HttpStatus.ACCEPTED)
    @PostMapping
    public ApiResponse<OutlineCreatedResponse> create(
            @AuthenticationPrincipal Long userId, @Valid @RequestBody CreateOutlineRequest request) {
        return ApiResponse.success(
                outlineService.createOutline(userId, request.title(), request.category(), request.toc()));
    }

    @Operation(summary = "뼈대 목록 조회")
    @GetMapping
    public ApiResponse<OutlineListResponse> list() {
        return ApiResponse.success(outlineService.listSummaries());
    }

    @Operation(summary = "뼈대 상세와 스텝별 채움 상태 조회")
    @GetMapping("/{outlineId}")
    public ApiResponse<OutlineDetailResponse> detail(@PathVariable Long outlineId) {
        return ApiResponse.success(outlineService.getDetail(outlineId));
    }

    @Operation(summary = "뼈대 제목·분류 수정")
    @PatchMapping("/{outlineId}")
    public ApiResponse<Void> update(@PathVariable Long outlineId, @Valid @RequestBody UpdateOutlineRequest request) {
        outlineService.updateOutline(outlineId, request.title(), request.category());
        return ApiResponse.success();
    }

    @Operation(summary = "뼈대 목차 변환을 다시 요청한다")
    @ResponseStatus(HttpStatus.ACCEPTED)
    @PostMapping("/{outlineId}/outline-jobs")
    public ApiResponse<JobCreatedResponse> regenerate(
            @AuthenticationPrincipal Long userId, @PathVariable Long outlineId) {
        return ApiResponse.success(new JobCreatedResponse(outlineService.regenerate(userId, outlineId)));
    }

    @Operation(summary = "승인된 뼈대를 학습자용 코스로 발행한다")
    @PostMapping("/{outlineId}/publish")
    public ApiResponse<PublishResponse> publish(@AuthenticationPrincipal Long userId, @PathVariable Long outlineId) {
        return ApiResponse.success(publishService.publish(userId, outlineId));
    }

    @Operation(summary = "뼈대에 수동 스텝 추가")
    @ResponseStatus(HttpStatus.CREATED)
    @PostMapping("/{outlineId}/steps")
    public ApiResponse<StepCreatedResponse> addStep(
            @PathVariable Long outlineId, @Valid @RequestBody CreateOutlineStepRequest request) {
        return ApiResponse.success(outlineService.addStep(outlineId, request.topic()));
    }
}
