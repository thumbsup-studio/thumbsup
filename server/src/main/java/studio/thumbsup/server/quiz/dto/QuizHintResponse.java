package studio.thumbsup.server.quiz.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import studio.thumbsup.server.quiz.Quiz;

/** 정답 제출 전에 사용자가 직접 요청하는 문제별 한 문장 힌트(#193). */
public record QuizHintResponse(
        @Schema(description = "정답을 직접 밝히지 않고 판단 단서를 제공하는 한 문장 힌트")
        String hint) {

    public static QuizHintResponse from(Quiz quiz) {
        return new QuizHintResponse(quiz.getHint());
    }
}
