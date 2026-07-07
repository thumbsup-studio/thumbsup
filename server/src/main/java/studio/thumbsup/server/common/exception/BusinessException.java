package studio.thumbsup.server.common.exception;

/**
 * 비즈니스 예외의 유일한 통로.
 *
 * <p>{@code IllegalArgumentException}/{@code IllegalStateException} 등 표준 예외를 직접 던지지 않는다
 * (ArchUnit이 CI에서 강제). 항상 ErrorType을 지정해 이 예외로 던지고, 변환은 전역 핸들러가 담당한다.
 */
public class BusinessException extends RuntimeException {

    private final ErrorType errorType;

    public BusinessException(ErrorType errorType) {
        super(errorType.getMessage());
        this.errorType = errorType;
    }

    public BusinessException(ErrorType errorType, Throwable cause) {
        super(errorType.getMessage(), cause);
        this.errorType = errorType;
    }

    public ErrorType getErrorType() {
        return errorType;
    }
}
