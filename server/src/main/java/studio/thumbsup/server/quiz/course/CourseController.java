package studio.thumbsup.server.quiz.course;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.quiz.course.dto.CourseListResponse;

/**
 * 컨트롤러는 얇게 — 검증·호출·envelope 감싸기만 한다.
 * 엔티티는 만질 수 없다(ArchUnit 강제) — DTO 변환은 Service에서 끝난다.
 */
@Tag(name = "Course", description = "코스")
@RestController
@RequestMapping("/api/v1/courses")
public class CourseController {

    private final CourseService courseService;

    public CourseController(CourseService courseService) {
        this.courseService = courseService;
    }

    @Operation(
            summary = "코스 목록 조회",
            description = "전체 코스와 코스별 스텝 목록을 반환한다. 각 스텝의 state는 로그인 유저의 진행 커서 기준으로 "
                    + "COMPLETED(완료)/SOLVABLE(오늘 풀 수 있음)/LOCKED(잠김) 중 하나다")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "조회 성공")
    @GetMapping
    public ApiResponse<CourseListResponse> getCourses(@AuthenticationPrincipal Long userId) {
        return ApiResponse.success(courseService.getCourses(userId));
    }
}
