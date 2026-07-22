package studio.thumbsup.server.notice;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;
import studio.thumbsup.server.common.response.CursorPage;
import studio.thumbsup.server.notice.dto.NoticeDetailResponse;
import studio.thumbsup.server.notice.dto.NoticeListResponse;

/**
 * 컨트롤러는 얇게 — 검증(어노테이션)·호출·envelope 감싸기만 한다.
 * 엔티티는 만질 수 없다(ArchUnit 강제) — DTO 변환은 Service에서 끝난다.
 */
@Tag(name = "Notice", description = "공지사항")
@Validated
@RestController
@RequestMapping("/api/v1/notices")
public class NoticeController {

    private final NoticeService noticeService;

    public NoticeController(NoticeService noticeService) {
        this.noticeService = noticeService;
    }

    @Operation(summary = "공지 목록 조회", description = "커서 페이지네이션 — meta.nextCursor를 다음 요청의 cursor로 전달")
    // 200을 명시하는 이유: springdoc은 @ApiResponse를 하나라도 선언하면 기본 성공 응답을 생성하지 않는다.
    // Swagger가 API 명세의 정본이므로(docs/api-standard.md §1) 성공 응답이 빠지면 FE가 계약을 볼 수 없다.
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "조회 성공")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(
            responseCode = "400",
            description = "code=INVALID_INPUT — size가 1~100 범위를 벗어나거나 cursor가 잘못됨")
    @GetMapping
    public ApiResponse<NoticeListResponse> getNotices(
            @RequestParam(required = false) String cursor,
            @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
        CursorPage<NoticeListResponse> page = noticeService.getNotices(cursor, size);
        return ApiResponse.success(page.data(), page.meta());
    }

    // 도메인 에러도 Swagger에 기재한다 — 에러 계약의 정본은 Swagger (docs/error-spec.md §2).
    // 200 명시 이유는 위 목록 조회와 동일 (springdoc이 @ApiResponse 선언 시 기본 성공 응답을 생략).
    @Operation(summary = "공지 상세 조회")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "조회 성공")
    @io.swagger.v3.oas.annotations.responses.ApiResponse(
            responseCode = "404",
            description = "code=NOTICE_NOT_FOUND — 존재하지 않는 공지")
    @GetMapping("/{noticeId}")
    public ApiResponse<NoticeDetailResponse> getNotice(@PathVariable Long noticeId) {
        return ApiResponse.success(noticeService.getNotice(noticeId));
    }
}
