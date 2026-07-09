package studio.thumbsup.server.learning;

import org.springframework.http.HttpStatus;
import studio.thumbsup.server.common.exception.ErrorType;

/**
 * 학습(코스·화·진행상태) 도메인 에러 — feature 소유 (common에 추가하지 않는다).
 * 코드 값 = enum 이름, 한 번 배포되면 변경 금지 (FE 분기가 깨진다).
 */
public enum LearningErrorType implements ErrorType {
    COURSE_NOT_FOUND(HttpStatus.NOT_FOUND, "학습 코스가 준비되지 않았습니다.");

    private final HttpStatus status;
    private final String message;

    LearningErrorType(HttpStatus status, String message) {
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
