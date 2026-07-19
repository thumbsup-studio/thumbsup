package studio.thumbsup.server.quiz.authoring;

import org.springframework.http.HttpStatus;
import studio.thumbsup.server.common.exception.ErrorType;

/**
 * 저작 파이프라인 도메인 에러 — feature 소유 (common에 추가하지 않는다).
 * 코드 값 = enum 이름, 한 번 배포되면 변경 금지 (FE 분기가 깨진다).
 */
public enum AuthoringErrorType implements ErrorType {
    AUTHORING_DRAFT_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 draft입니다."),
    AUTHORING_JOB_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 잡입니다."),
    AUTHORING_DRAFT_JOB_ACTIVE(HttpStatus.CONFLICT, "이 draft에 진행 중인 잡이 있습니다."),
    AUTHORING_IMPROVE_DRAFT_EXISTS(HttpStatus.CONFLICT, "이 문제에 이미 열린 개선 draft가 있습니다."),
    AUTHORING_DRAFT_ALREADY_APPROVED(HttpStatus.CONFLICT, "이미 승인된 draft입니다."),
    AUTHORING_JOB_NOT_CLAIMABLE(HttpStatus.CONFLICT, "결과를 제출할 수 있는 상태가 아닙니다."),
    AUTHORING_COURSE_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 코스입니다.");

    private final HttpStatus status;
    private final String message;

    AuthoringErrorType(HttpStatus status, String message) {
        this.status = status;
        this.message = message;
    }

    @Override
    public HttpStatus getStatus() {
        return status;
    }

    @Override
    public String getCode() {
        return name();
    }

    @Override
    public String getMessage() {
        return message;
    }
}
