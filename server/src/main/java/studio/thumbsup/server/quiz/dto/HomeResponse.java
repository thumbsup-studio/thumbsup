package studio.thumbsup.server.quiz.dto;

import studio.thumbsup.server.quiz.Course;
import studio.thumbsup.server.quiz.QuizStep;

/**
 * 홈 화면 조회 응답 — 스트릭·포인트·오늘의 학습 진입점을 한 번에 담는다.
 * 필드명은 앱 홈(#2/#52)이 이미 쓰는 courseTitle/unitTitle/streakDays와 정렬한다
 * (app/src/features/play/types.ts, app/src/features/home/types.ts 참조).
 */
public record HomeResponse(int streakDays, int points, boolean todayCompleted, TodayLearning today) {

    /** 오늘의 학습 카드에 필요한 진입점 정보 — 정답을 맞히는 데 필요한 문제 본문은 담지 않는다(퀴즈 조회 API 몫). */
    public record TodayLearning(
            Long courseId,
            String courseTitle,
            Long unitId,
            String unitTitle,
            int order,
            int completedCount,
            int totalCount,
            int estimatedMinutes) {

        static TodayLearning of(Course course, QuizStep current, int completedCount, int totalCount) {
            return new TodayLearning(
                    course.getId(),
                    course.getTitle(),
                    current.getId(),
                    current.getTopic(),
                    current.getStepOrder(),
                    completedCount,
                    totalCount,
                    current.getEstimatedMinutes());
        }
    }

    public static HomeResponse from(
            int streakDays, int points, boolean todayCompleted, Course course, QuizStep current, int totalCount) {
        int completedCount = current.getStepOrder() - 1;
        return new HomeResponse(
                streakDays, points, todayCompleted, TodayLearning.of(course, current, completedCount, totalCount));
    }
}
