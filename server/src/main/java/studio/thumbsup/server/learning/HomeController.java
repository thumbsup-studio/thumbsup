package studio.thumbsup.server.learning;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.learning.dto.HomeResponse;

/**
 * 컨트롤러는 얇게 — 검증·호출·envelope 감싸기만 한다.
 * 엔티티는 만질 수 없다(ArchUnit 강제) — DTO 변환은 Service에서 끝난다.
 */
@Tag(name = "Home", description = "홈 화면")
@RestController
@RequestMapping("/api/v1/home")
public class HomeController {

    private final HomeService homeService;

    public HomeController(HomeService homeService) {
        this.homeService = homeService;
    }

    @Operation(summary = "홈 화면 조회", description = "스트릭·포인트·오늘의 학습 진입점을 모아 반환한다")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(
            responseCode = "404",
            description = "code=COURSE_NOT_FOUND — 학습 코스가 준비되지 않음(운영 설정 누락)")
    @GetMapping
    public ApiResponse<HomeResponse> getHome(@AuthenticationPrincipal Long userId) {
        return ApiResponse.success(homeService.getHome(userId));
    }
}
