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
import studio.thumbsup.server.quiz.dto.QuizExplanationResponse;
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

    @Operation(
            summary = "해설 조회",
            description = "문제 ID로 문제 본문·유형·난이도·현재 순번·전체 문제 수·대주제·소주제와 "
                    + "해설(핵심 N줄 정리·예시·오답 해설), 키워드 툴팁 설명, 꼬리질문을 한 번에 조회한다. "
                    + "본문 속 키워드 위치는 highlights 구간으로 내려간다. 채점 결과는 담지 않는다(정답 제출 API 담당)")
    // 200을 명시하는 이유: springdoc은 @ApiResponse를 하나라도 선언하면 기본 성공 응답을 생성하지 않는다.
    // Swagger가 API 명세의 정본이므로(docs/api-standard.md §1) 성공 응답이 빠지면 FE가 계약을 볼 수 없다.
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "조회 성공")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(
            responseCode = "404",
            description = "code=QUIZ_NOT_FOUND — 존재하지 않는 퀴즈; " + "code=COURSE_NOT_FOUND — 기본 학습 코스가 준비되지 않음")
    @GetMapping("/{quizId}/explanation")
    public ApiResponse<QuizExplanationResponse> getExplanation(@PathVariable Long quizId) {
        return ApiResponse.success(quizService.getExplanation(quizId));
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
