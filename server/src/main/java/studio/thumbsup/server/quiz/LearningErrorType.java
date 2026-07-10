package studio.thumbsup.server.quiz;

import org.springframework.http.HttpStatus;
import studio.thumbsup.server.common.exception.ErrorType;

/**
 * 홈/학습 진행 관련 에러. {@link QuizErrorType}과 별개로 둔 이유는 "퀴즈 풀이"와 "홈 화면 조립"이
 * 실패하는 이유가 서로 달라서다(코드 값 = enum 이름, 한 번 배포되면 변경 금지 — FE 분기가 깨진다).
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
