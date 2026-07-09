package studio.thumbsup.server.quiz.generation;

/**
 * 문제 생성 파이프라인 전용 예외 — CLI 전용 도구라 HTTP 계약(BusinessException/ErrorType)과 무관하다.
 * java.* 표준 예외가 아니라 ArchUnit "표준 예외 생성 금지" 규칙 대상이 아니다.
 */
public class QuizGenerationException extends RuntimeException {

    public QuizGenerationException(String message) {
        super(message);
    }

    public QuizGenerationException(String message, Throwable cause) {
        super(message, cause);
    }
}
