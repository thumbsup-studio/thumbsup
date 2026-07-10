package studio.thumbsup.server.mascot;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.mascot.dto.MascotResponse;

/**
 * 컨트롤러는 얇게 — 검증·호출·envelope 감싸기만 한다.
 * 엔티티는 만질 수 없다(ArchUnit 강제) — DTO 변환은 Service에서 끝난다.
 */
@Tag(name = "Mascot", description = "홈 캐릭터 '보리'")
@RestController
@RequestMapping("/api/v1/mascot")
public class MascotController {

    private final MascotService mascotService;

    public MascotController(MascotService mascotService) {
        this.mascotService = mascotService;
    }

    @Operation(summary = "보리 상태 조회", description = "이름·포만감(시간 경과에 따른 감소 반영)을 반환한다")
    @GetMapping
    public ApiResponse<MascotResponse> getMascot(@AuthenticationPrincipal Long userId) {
        return ApiResponse.success(mascotService.getMascot(userId));
    }

    @Operation(summary = "먹이 주기", description = "세션(퀴즈 5문제) 완료 시 호출 — 포만감을 올린다")
    @PostMapping("/feed")
    public ApiResponse<MascotResponse> feed(@AuthenticationPrincipal Long userId) {
        return ApiResponse.success(mascotService.feed(userId));
    }
}
