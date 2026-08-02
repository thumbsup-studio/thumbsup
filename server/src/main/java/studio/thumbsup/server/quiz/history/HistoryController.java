package studio.thumbsup.server.quiz.history;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.quiz.history.dto.HistoryGraphResponse;

/**
 * 컨트롤러는 얇게 — 검증·호출·envelope 감싸기만 한다.
 * 엔티티는 만질 수 없다(ArchUnit 강제) — DTO 변환은 Service에서 끝난다.
 */
@Tag(name = "History", description = "학습 이력·지식 그래프")
@RestController
@RequestMapping("/api/v1/history")
public class HistoryController {

    private final HistoryService historyService;

    public HistoryController(HistoryService historyService) {
        this.historyService = historyService;
    }

    @Operation(
            summary = "지식 그래프 조회",
            description =
                    "인증된 유저가 실제로 학습(완료)한 개념을 노드로, 개념 간 관계를 엣지로 반환한다. " + "학습한 개념이 없으면 에러가 아니라 빈 nodes/edges로 응답한다")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "조회 성공")
    @GetMapping("/graph")
    public ApiResponse<HistoryGraphResponse> getGraph(@AuthenticationPrincipal Long userId) {
        return ApiResponse.success(historyService.getGraph(userId));
    }
}
