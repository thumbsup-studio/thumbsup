package studio.thumbsup.server.quiz.authoring;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseDetailResponse;
import studio.thumbsup.server.quiz.authoring.dto.AuthoringCourseListResponse;

/**
 * 코스 인덱스·코스별 라이브 문제 상세 조회(#182). 컨트롤러는 얇게 — 호출·envelope만.
 */
@Tag(name = "Authoring Course", description = "코스별 라이브 문제 상세 조회")
@RestController
@RequestMapping("/api/v1/authoring/courses")
public class AuthoringCourseController {

    private final AuthoringCourseService courseService;

    public AuthoringCourseController(AuthoringCourseService courseService) {
        this.courseService = courseService;
    }

    @Operation(summary = "코스 목록 조회")
    @GetMapping
    public ApiResponse<AuthoringCourseListResponse> list() {
        return ApiResponse.success(courseService.listCourses());
    }

    @Operation(summary = "코스별 라이브 문제를 스텝별로 그룹핑해 전체 상세와 함께 조회")
    @GetMapping("/{courseId}/quizzes")
    public ApiResponse<AuthoringCourseDetailResponse> quizzes(@PathVariable Long courseId) {
        return ApiResponse.success(courseService.getCourseQuizzes(courseId));
    }
}
