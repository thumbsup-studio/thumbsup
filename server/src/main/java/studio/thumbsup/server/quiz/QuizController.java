package studio.thumbsup.server.quiz;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.quiz.dto.AnswerSubmitRequest;
import studio.thumbsup.server.quiz.dto.AnswerSubmitResponse;
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

    @Operation(summary = "정답 제출", description = "제출한 답을 채점하고 풀이 이력을 기록한다. 스텝을 모두 시도하면 다음 스텝으로 진행된다")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(
            responseCode = "404",
            description = "code=QUIZ_NOT_FOUND — 존재하지 않는 퀴즈")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(
            responseCode = "403",
            description = "code=QUIZ_NOT_ACCESSIBLE — 아직 진행하지 않은 미래 스텝의 문제")
    @PostMapping("/{quizId}/answers")
    public ApiResponse<AnswerSubmitResponse> submitAnswer(
            @AuthenticationPrincipal Long userId,
            @PathVariable Long quizId,
            @Valid @RequestBody AnswerSubmitRequest request) {
        return ApiResponse.success(quizService.submitAnswer(userId, quizId, request));
    }
}
