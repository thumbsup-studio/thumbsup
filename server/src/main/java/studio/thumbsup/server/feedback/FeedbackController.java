package studio.thumbsup.server.feedback;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.feedback.dto.FeedbackCreateRequest;
import studio.thumbsup.server.feedback.dto.FeedbackCreateResponse;

/**
 * 컨트롤러는 얇게 — 검증(어노테이션)·호출·envelope 감싸기만 한다.
 * 엔티티는 만질 수 없다(ArchUnit 강제) — DTO 변환은 Service에서 끝난다.
 */
@Tag(name = "Feedback", description = "의견 보내기")
@RestController
@RequestMapping("/api/v1/feedbacks")
public class FeedbackController {

    private final FeedbackService feedbackService;

    public FeedbackController(FeedbackService feedbackService) {
        this.feedbackService = feedbackService;
    }

    @Operation(summary = "의견 보내기")
    @ResponseStatus(HttpStatus.CREATED)
    @PostMapping
    public ApiResponse<FeedbackCreateResponse> createFeedback(
            @AuthenticationPrincipal Long userId, @Valid @RequestBody FeedbackCreateRequest request) {
        return ApiResponse.success(feedbackService.create(userId, request));
    }
}
