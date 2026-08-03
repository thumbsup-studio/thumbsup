package studio.thumbsup.server.quiz.dto;

import java.time.OffsetDateTime;
import java.util.List;
import studio.thumbsup.server.common.time.TimeZones;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizAttempt;
import studio.thumbsup.server.quiz.QuizChoice;
import studio.thumbsup.server.quiz.QuizType;

/**
 * GET /api/v1/quizzes/attempts 전용 응답 DTO — 다른 API와 공유하지 않는다.
 * 리스트 키는 항상 {@code items} (docs/api-standard.md §4).
 */
public record QuizAttemptHistoryResponse(List<QuizAttemptHistoryItem> items) {

    public static QuizAttemptHistoryResponse from(List<QuizAttempt> attempts) {
        return new QuizAttemptHistoryResponse(
                attempts.stream().map(QuizAttemptHistoryItem::from).toList());
    }

    public record QuizAttemptHistoryItem(
            Long attemptId,
            Long quizId,
            QuizType type,
            String questionText,
            String selectedAnswer,
            boolean isCorrect,
            OffsetDateTime submittedAt) {

        private static QuizAttemptHistoryItem from(QuizAttempt attempt) {
            Quiz quiz = attempt.getQuiz();
            return new QuizAttemptHistoryItem(
                    attempt.getId(),
                    quiz.getId(),
                    quiz.getType(),
                    quiz.getQuestionText(),
                    resolveDisplayAnswer(quiz, attempt.getSelectedAnswer()),
                    attempt.isCorrect(),
                    attempt.getCreatedAt().atZone(TimeZones.KST).toOffsetDateTime()); // UTC 저장 → KST 직렬화
        }

        /**
         * 저장된 원본 답을 화면에 보여줄 문구로 바꾼다. OX는 이미 읽을 수 있는 값("O"/"X")이라 그대로 두고,
         * 빈칸은 쉼표로 이어붙인 저장값을 다시 나눠 보기 좋게 잇는다. 사지선다만 저장된 choiceId를
         * 선택지 문구로 치환한다 — 화면에 숫자 id를 그대로 보여주는 건 무의미하다.
         * 이 필드 도입 이전 시도(selectedAnswer=null)는 실제로 알 수 없는 값을 지어내지 않고 null을 유지한다.
         */
        private static String resolveDisplayAnswer(Quiz quiz, String rawSelectedAnswer) {
            if (rawSelectedAnswer == null) {
                return null;
            }
            if (quiz.getType() == QuizType.KEYWORD_BLANK) {
                return String.join(", ", rawSelectedAnswer.split(","));
            }
            if (quiz.getType() != QuizType.MULTIPLE_CHOICE) {
                return rawSelectedAnswer;
            }
            return resolveChoiceContent(quiz, rawSelectedAnswer);
        }

        /** 선택지가 데이터 정합성 문제 등으로 더 이상 존재하지 않으면 null(화면은 "알 수 없음"류로 처리). */
        private static String resolveChoiceContent(Quiz quiz, String rawChoiceId) {
            Long choiceId;
            try {
                choiceId = Long.valueOf(rawChoiceId);
            } catch (NumberFormatException e) {
                return null;
            }
            return quiz.getChoices().stream()
                    .filter(choice -> choice.getId().equals(choiceId))
                    .findFirst()
                    .map(QuizChoice::getContent)
                    .orElse(null);
        }
    }
}
