package studio.thumbsup.server.quiz.authoring;

import java.util.List;

/** 스텝 문제 생성에 주입하는 코스·인접 스텝·기존 문제 맥락. */
public record OutlineStepContext(
        String courseTitle,
        int orderNo,
        int totalSteps,
        String topic,
        String learningGoal,
        String prevTopic,
        String nextTopic,
        List<String> existingQuestions) {}
