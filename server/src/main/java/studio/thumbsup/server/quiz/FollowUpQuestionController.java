package studio.thumbsup.server.quiz;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.quiz.dto.FollowUpQuestionDetailResponse;

/**
 * 컨트롤러는 얇게 — 검증·호출·envelope 감싸기만 한다.
 * 엔티티는 만질 수 없다(ArchUnit 강제) — DTO 변환은 Service에서 끝난다.
 */
@Tag(name = "FollowUpQuestion", description = "꼬리질문")
@RestController
@RequestMapping("/api/v1/follow-up-questions")
public class FollowUpQuestionController {

    private final QuizFollowUpQuestionService quizFollowUpQuestionService;

    public FollowUpQuestionController(QuizFollowUpQuestionService quizFollowUpQuestionService) {
        this.quizFollowUpQuestionService = quizFollowUpQuestionService;
    }

    @Operation(
            summary = "꼬리질문 상세 조회",
            description = "해설 조회 응답의 followUpQuestionId로 꼬리질문 화면 콘텐츠를 조회한다. "
                    + "출처 문제 순번·난이도·질문 본문·한 줄 답·상세 정리 블록·키워드 툴팁 설명을 한 번에 반환한다. "
                    + "본문 속 키워드 위치는 highlights 구간으로 내려간다. 풀이·채점이 없는 읽기 전용 화면이라 "
                    + "세션 진행도는 담지 않는다")
    // 200을 명시하는 이유: springdoc은 @ApiResponse를 하나라도 선언하면 기본 성공 응답을 생성하지 않는다.
    // Swagger가 API 명세의 정본이므로(docs/api-standard.md §1) 성공 응답이 빠지면 FE가 계약을 볼 수 없다.
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "조회 성공")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(
            responseCode = "404",
            description = "code=FOLLOW_UP_QUESTION_NOT_FOUND — 존재하지 않는 꼬리질문; "
                    + "code=FOLLOW_UP_DETAIL_NOT_FOUND — 상세 콘텐츠가 아직 저작되지 않은 꼬리질문")
    @GetMapping("/{followUpQuestionId}")
    public ApiResponse<FollowUpQuestionDetailResponse> getFollowUpQuestion(@PathVariable Long followUpQuestionId) {
        return ApiResponse.success(quizFollowUpQuestionService.getDetail(followUpQuestionId));
    }
}
