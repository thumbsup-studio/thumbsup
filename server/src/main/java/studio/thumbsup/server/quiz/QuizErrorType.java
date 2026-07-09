package studio.thumbsup.server.quiz;

import org.springframework.http.HttpStatus;
import studio.thumbsup.server.common.exception.ErrorType;

/**
 * 퀴즈 도메인 에러 — feature 소유 (common에 추가하지 않는다).
 * 코드 값 = enum 이름, 한 번 배포되면 변경 금지 (FE 분기가 깨진다).
 */
public enum QuizErrorType implements ErrorType {
    QUIZ_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 퀴즈입니다."),
    QUIZ_STEP_COMPLETED(HttpStatus.NOT_FOUND, "현재 스텝의 문제를 모두 풀었습니다."),
    QUIZ_NOT_ACCESSIBLE(HttpStatus.FORBIDDEN, "아직 진행할 수 없는 문제입니다.");

    private final HttpStatus status;
    private final String message;

    QuizErrorType(HttpStatus status, String message) {
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
