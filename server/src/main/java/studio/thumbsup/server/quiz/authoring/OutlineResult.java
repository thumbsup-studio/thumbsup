package studio.thumbsup.server.quiz.authoring;

import java.util.List;

/** OUTLINE 잡이 반환하는 목차 재구성 결과. */
public record OutlineResult(List<OutlineStepResult> steps) {

    public record OutlineStepResult(String topic, String learningGoal) {}
}
