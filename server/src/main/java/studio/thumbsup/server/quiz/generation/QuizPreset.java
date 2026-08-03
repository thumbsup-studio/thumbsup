package studio.thumbsup.server.quiz.generation;

import java.util.Arrays;
import java.util.List;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizType;

/** 문제 세션을 구성하는 사전 정의 슬롯 프리셋. */
public enum QuizPreset {
    BASIC_5(3, QuizType.OX, QuizType.OX, QuizType.MULTIPLE_CHOICE, QuizType.MULTIPLE_CHOICE, QuizType.KEYWORD_BLANK),
    LIGHT_3(2, QuizType.OX, QuizType.MULTIPLE_CHOICE, QuizType.KEYWORD_BLANK),
    DEEP_7(
            5,
            QuizType.OX,
            QuizType.OX,
            QuizType.MULTIPLE_CHOICE,
            QuizType.MULTIPLE_CHOICE,
            QuizType.MULTIPLE_CHOICE,
            QuizType.KEYWORD_BLANK,
            QuizType.KEYWORD_BLANK);

    private final int estimatedMinutes;
    private final List<Slot> slots;

    QuizPreset(int estimatedMinutes, QuizType... types) {
        this.estimatedMinutes = estimatedMinutes;
        this.slots = Arrays.stream(types)
                .map(type -> new Slot(type, difficultyOf(type)))
                .toList();
    }

    public record Slot(QuizType type, QuizDifficulty difficulty) {}

    private static QuizDifficulty difficultyOf(QuizType type) {
        if (type == QuizType.OX) {
            return QuizDifficulty.EASY;
        }
        if (type == QuizType.MULTIPLE_CHOICE) {
            return QuizDifficulty.MEDIUM;
        }
        return QuizDifficulty.HARD;
    }

    public List<Slot> slots() {
        return slots;
    }

    public int quizCount() {
        return slots.size();
    }

    public int estimatedMinutes() {
        return estimatedMinutes;
    }
}
