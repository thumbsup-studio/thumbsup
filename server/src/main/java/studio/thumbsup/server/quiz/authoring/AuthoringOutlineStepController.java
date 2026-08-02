package studio.thumbsup.server.quiz.authoring;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.quiz.authoring.dto.ReorderStepRequest;
import studio.thumbsup.server.quiz.authoring.dto.UpdateOutlineStepRequest;

@Tag(name = "Authoring Outline Step", description = "저작 코스 뼈대 스텝 편집")
@RestController
@RequestMapping("/api/v1/authoring/outline-steps")
public class AuthoringOutlineStepController {

    private final AuthoringOutlineService outlineService;

    public AuthoringOutlineStepController(AuthoringOutlineService outlineService) {
        this.outlineService = outlineService;
    }

    @Operation(summary = "뼈대 스텝 주제 수정")
    @PatchMapping("/{stepId}")
    public ApiResponse<Void> update(@PathVariable Long stepId, @Valid @RequestBody UpdateOutlineStepRequest request) {
        outlineService.updateStep(stepId, request.topic());
        return ApiResponse.success();
    }

    @Operation(summary = "뼈대 스텝 삭제")
    @DeleteMapping("/{stepId}")
    public ApiResponse<Void> delete(@PathVariable Long stepId) {
        outlineService.deleteStep(stepId);
        return ApiResponse.success();
    }

    @Operation(summary = "뼈대 스텝 순서 변경")
    @PatchMapping("/{stepId}/order")
    public ApiResponse<Void> reorder(@PathVariable Long stepId, @Valid @RequestBody ReorderStepRequest request) {
        outlineService.reorderStep(stepId, request.direction());
        return ApiResponse.success();
    }
}
