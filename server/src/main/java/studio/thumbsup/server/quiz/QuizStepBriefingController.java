package studio.thumbsup.server.quiz;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.quiz.dto.QuizNextResponse;
import studio.thumbsup.server.quiz.dto.QuizStepBriefingResponse;

/** 일반 학습 시작 전에 현재 스텝의 개념 브리핑을 제공하는 API. */
@Tag(name = "Quiz Step Briefing", description = "문제 풀이 전 스텝 개념 브리핑")
@RestController
@RequestMapping("/api/v1")
public class QuizStepBriefingController {

    private final QuizStepBriefingService quizStepBriefingService;

    public QuizStepBriefingController(QuizStepBriefingService quizStepBriefingService) {
        this.quizStepBriefingService = quizStepBriefingService;
    }

    @Operation(summary = "현재 스텝 브리핑 조회", description = "사용자의 해당 코스 진행도에서 현재 풀이할 스텝의 요약과 개념 설명 블록을 반환한다.")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "브리핑 조회 성공")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(
            responseCode = "404",
            description = "code=QUIZ_NOT_FOUND — 코스 또는 현재 스텝이 없음; " + "code=QUIZ_STEP_COMPLETED — 코스를 완주함")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(
            responseCode = "409",
            description = "code=QUIZ_STEP_BRIEFING_NOT_AVAILABLE — 브리핑 미준비")
    @GetMapping("/courses/{courseId}/next-step/briefing")
    public ApiResponse<QuizStepBriefingResponse> getNextBriefing(
            @AuthenticationPrincipal Long userId, @PathVariable Long courseId) {
        return ApiResponse.success(quizStepBriefingService.getNextBriefing(userId, courseId));
    }

    @Operation(summary = "브리핑 스텝의 다음 문제 조회", description = "브리핑에서 받은 quizStepId가 현재 풀 차례인 경우에만 그 스텝의 미시도 다음 문제를 반환한다.")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "다음 문제 조회 성공")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(
            responseCode = "403",
            description = "code=QUIZ_NOT_ACCESSIBLE — 아직 풀이할 수 없는 미래 스텝")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(
            responseCode = "404",
            description = "code=QUIZ_NOT_FOUND — 존재하지 않는 스텝 또는 문제; " + "code=QUIZ_STEP_COMPLETED — 스텝의 모든 문제를 시도함")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(
            responseCode = "409",
            description = "code=QUIZ_STEP_NOT_CURRENT — 완료한 과거 스텝")
    @GetMapping("/quiz-steps/{quizStepId}/quizzes/next")
    public ApiResponse<QuizNextResponse> getNextQuizForStep(
            @AuthenticationPrincipal Long userId, @PathVariable Long quizStepId) {
        return ApiResponse.success(quizStepBriefingService.getNextQuizForStep(userId, quizStepId));
    }
}
