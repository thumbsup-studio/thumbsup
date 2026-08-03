package studio.thumbsup.server.quiz;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.quiz.dto.HomeResponse;

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

    @Operation(
            summary = "홈 화면 조회",
            description = "스트릭·포인트와 학습 중인 코스 목록(최근 푼 순 최대 10개)을 반환한다. " + "진행 중인 코스가 없으면(신규 유저) 첫 번째 코스 하나를 목록에 담아 준다")
    // 200 명시 이유: springdoc은 @ApiResponse를 하나라도 선언하면 기본 성공 응답을 생성하지 않는다 (notice 참조).
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "조회 성공")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(
            responseCode = "404",
            description = "code=COURSE_NOT_FOUND — 학습 코스가 준비되지 않음(운영 설정 누락)")
    @GetMapping
    public ApiResponse<HomeResponse> getHome(@AuthenticationPrincipal Long userId) {
        return ApiResponse.success(homeService.getHome(userId));
    }
}
