package studio.thumbsup.server.quiz.dto;

import java.util.List;
import studio.thumbsup.server.quiz.QuizStep;

/** 유저가 완료한 스텝 이력 — 히스토리 화면(#10)에 스텝번호·주제명만 표시한다. */
public record QuizStepHistoryResponse(List<Item> steps) {

    public record Item(int stepOrder, String topic) {

        static Item of(QuizStep step) {
            return new Item(step.getStepOrder(), step.getTopic());
        }
    }

    public static QuizStepHistoryResponse from(List<QuizStep> completedSteps) {
        return new QuizStepHistoryResponse(completedSteps.stream().map(Item::of).toList());
    }
}
