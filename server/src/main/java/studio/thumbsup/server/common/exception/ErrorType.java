package studio.thumbsup.server.common.exception;

import org.springframework.http.HttpStatus;

/**
 * 에러 코드 계약 — docs/error-spec.md, server/docs/error-implementation.md.
 *
 * <p>각 feature가 자체 enum으로 구현한다 (예: {@code QuizErrorType implements ErrorType}).
 * 중앙 enum 하나에 모으지 않는다 — API 추가마다 common/을 수정하게 되어 병렬 작업의 충돌 지점이 된다.
 * 공통 에러만 {@link CommonErrorType}에 둔다.
 */
public interface ErrorType {

    /** HTTP status — 대분류 (400/401/403/404/500) */
    HttpStatus getStatus();

    /** 응답 envelope의 code — UPPER_SNAKE_CASE, 한 번 배포되면 변경 금지 (FE 분기가 깨진다) */
    String getCode();

    /** 사용자에게 그대로 노출 가능한 한국어 기본 문구 */
    String getMessage();
}
