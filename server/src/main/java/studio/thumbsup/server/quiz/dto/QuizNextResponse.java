package studio.thumbsup.server.quiz.dto;

import java.util.List;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizChoice;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizType;

/**
 * "다음 문제 조회" 응답 — 정답을 맞히는 데 필요한 정보만 내려간다.
 * 정답(correctAnswer/answerKeywords의 값/choices의 isCorrect)과 해설은 포함하지 않는다
 * (정답 확인은 #42, 해설은 #43의 몫).
 */
public record QuizNextResponse(
        Long quizId,
        QuizType type,
        QuizDifficulty difficulty,
        String questionText,
        String codeSnippet,
        List<ChoiceItem> choices,
        Integer blankCount,
        Long courseId,
        int stepOrder,
        int slotOrder,
        int totalCount) {

    public record ChoiceItem(Long choiceId, String content, int displayOrder) {

        static ChoiceItem from(QuizChoice choice) {
            return new ChoiceItem(choice.getId(), choice.getContent(), choice.getDisplayOrder());
        }
    }

    /**
     * @param courseId stepOrder가 코스 내 상대 순번이라(#292) 재풀이 API 호출 시 함께 넘겨야 한다.
     * @param totalCount 이 문제가 속한 스텝의 전체 문제 수 — 앱의 진행 표시(n/총)와 완주 판정에 쓰인다(#266).
     *     스텝마다 문제 수가 다를 수 있어 클라이언트가 상수로 가정할 수 없다.
     */
    public static QuizNextResponse from(Quiz quiz, Long courseId, int totalCount) {
        List<ChoiceItem> choiceItems = quiz.getType() == QuizType.MULTIPLE_CHOICE
                ? quiz.getChoices().stream().map(ChoiceItem::from).toList()
                : null;
        Integer blankCount = quiz.getType() == QuizType.KEYWORD_BLANK
                ? Math.toIntExact(quiz.getAnswerKeywords().stream()
                        .mapToInt(answerKeyword -> answerKeyword.getSlotOrder())
                        .distinct()
                        .count())
                : null;
        return new QuizNextResponse(
                quiz.getId(),
                quiz.getType(),
                quiz.getDifficulty(),
                quiz.getQuestionText(),
                quiz.getCodeSnippet(),
                choiceItems,
                blankCount,
                courseId,
                quiz.getStepOrder(),
                quiz.getSlotOrder(),
                totalCount);
    }
}
