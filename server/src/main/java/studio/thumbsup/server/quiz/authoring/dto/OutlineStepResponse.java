package studio.thumbsup.server.quiz.authoring.dto;

import studio.thumbsup.server.quiz.authoring.OutlineStepFillState;

public record OutlineStepResponse(
        Long stepId,
        int orderNo,
        String topic,
        String learningGoal,
        OutlineStepFillState fillState,
        Long draftId,
        Long activeJobId) {}
