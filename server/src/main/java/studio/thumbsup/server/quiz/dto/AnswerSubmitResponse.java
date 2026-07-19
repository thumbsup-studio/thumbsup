package studio.thumbsup.server.quiz.dto;

/**
 * 채점 결과. {@code retryHint}는 오답이고 중·상 난이도일 때만 채워지고 그 외에는 {@code null}이라,
 * 이 필드를 읽지 않는 기존 클라이언트는 그대로 동작한다(#63).
 */
public record AnswerSubmitResponse(boolean isCorrect, RetryHint retryHint) {}
