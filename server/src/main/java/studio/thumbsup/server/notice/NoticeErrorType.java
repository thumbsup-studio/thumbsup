package studio.thumbsup.server.notice;

import org.springframework.http.HttpStatus;
import studio.thumbsup.server.common.exception.ErrorType;

/**
 * 공지 도메인 에러 — feature 소유 (common에 추가하지 않는다).
 * 코드 값 = enum 이름, 한 번 배포되면 변경 금지 (FE 분기가 깨진다).
 */
public enum NoticeErrorType implements ErrorType {
    NOTICE_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 공지입니다.");

    private final HttpStatus status;
    private final String message;

    NoticeErrorType(HttpStatus status, String message) {
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
