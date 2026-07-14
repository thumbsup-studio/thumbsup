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
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringQuizListResponse;
import studio.thumbsup.server.quiz.authoring.dto.ImproveCreatedResponse;
import studio.thumbsup.server.quiz.authoring.dto.ImproveRequest;

/**
 * 컨트롤러는 얇게 — 검증(어노테이션)·호출·envelope 감싸기만 한다.
 * 엔티티는 만질 수 없다(ArchUnit 강제) — DTO 변환은 Service에서 끝난다.
 */
@Tag(name = "Authoring Quiz", description = "라이브 문제 조회·개선 요청")
@RestController
@RequestMapping("/api/v1/authoring/quizzes")
public class AuthoringQuizController {

    private final AuthoringJobService jobService;
    private final AuthoringQuizService quizService;

    public AuthoringQuizController(AuthoringJobService jobService, AuthoringQuizService quizService) {
        this.jobService = jobService;
        this.quizService = quizService;
    }

    @Operation(summary = "라이브 문제를 개선 대상으로 복제하고 검수 잡을 큐에 넣는다")
    @ResponseStatus(HttpStatus.ACCEPTED)
    @PostMapping("/{quizId}/improve")
    public ApiResponse<ImproveCreatedResponse> improve(
            @AuthenticationPrincipal Long userId,
            @PathVariable Long quizId,
            @Valid @RequestBody ImproveRequest request) {
        AuthoringJobService.ImproveEnqueued enqueued = jobService.enqueueImprove(userId, quizId, request.instruction());
        return ApiResponse.success(new ImproveCreatedResponse(enqueued.draftId(), enqueued.jobId()));
    }

    @Operation(summary = "스텝별로 그룹핑한 라이브 문제 목록 조회")
    @GetMapping
    public ApiResponse<AuthoringQuizListResponse> list() {
        return ApiResponse.success(quizService.listQuizzes());
    }
}
