package studio.thumbsup.server.quiz;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.quiz.dto.QuizNextResponse;

/**
 * 컨트롤러는 얇게 — 검증·호출·envelope 감싸기만 한다.
 * 엔티티는 만질 수 없다(ArchUnit 강제) — DTO 변환은 Service에서 끝난다.
 */
@Tag(name = "Quiz", description = "퀴즈 문제")
@RestController
@RequestMapping("/api/v1/quizzes")
public class QuizController {

    private final QuizService quizService;

    public QuizController(QuizService quizService) {
        this.quizService = quizService;
    }

    @Operation(summary = "다음 문제 조회", description = "유저의 현재 진행 스텝에서 아직 풀지 않은 다음 문제를 반환한다")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(
            responseCode = "404",
            description = "code=QUIZ_STEP_COMPLETED — 현재 스텝을 모두 풀어 진행 갱신이 필요함")
    @GetMapping("/next")
    public ApiResponse<QuizNextResponse> getNextQuiz(@AuthenticationPrincipal Long userId) {
        return ApiResponse.success(quizService.getNextQuiz(userId));
    }
}
