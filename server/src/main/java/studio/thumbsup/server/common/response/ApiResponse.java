package studio.thumbsup.server.common.response;

import studio.thumbsup.server.common.exception.ErrorType;

/**
 * 모든 API 응답의 공통 envelope — 계약: docs/api-standard.md §2.
 *
 * <p>성공/에러 모두 이 형태로만 응답한다. 204(No Content)는 쓰지 않는다.
 */
public record ApiResponse<T>(String code, String message, T data, Object meta) {

    private static final String SUCCESS_CODE = "SUCCESS";
    private static final String SUCCESS_MESSAGE = "OK";

    public static <T> ApiResponse<T> success(T data) {
        return new ApiResponse<>(SUCCESS_CODE, SUCCESS_MESSAGE, data, null);
    }

    /** 커서 페이지네이션 등 부가정보가 있는 성공 응답 — meta에 {@link CursorMeta} 등을 담는다. */
    public static <T> ApiResponse<T> success(T data, Object meta) {
        return new ApiResponse<>(SUCCESS_CODE, SUCCESS_MESSAGE, data, meta);
    }

    /** 반환할 데이터가 없는 성공 응답 (예: 삭제) — data는 null로 내려간다. */
    public static ApiResponse<Void> success() {
        return new ApiResponse<>(SUCCESS_CODE, SUCCESS_MESSAGE, null, null);
    }

    public static <T> ApiResponse<T> error(ErrorType errorType) {
        return new ApiResponse<>(errorType.getCode(), errorType.getMessage(), null, null);
    }

    /** 에러 상세 payload가 필요한 경우 (예: 검증 실패의 fieldErrors) */
    public static <T> ApiResponse<T> error(ErrorType errorType, T data) {
        return new ApiResponse<>(errorType.getCode(), errorType.getMessage(), data, null);
    }
}
