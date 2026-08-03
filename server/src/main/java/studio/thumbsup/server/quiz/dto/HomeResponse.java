package studio.thumbsup.server.quiz.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.course.Course;

/**
 * 홈 화면 조회 응답 — 스트릭·포인트와 학습 중인 코스 목록(최근 푼 순 최대 10개, #240)을 한 번에 담는다.
 * 아이템 필드명은 앱 홈(#2/#52)이 이미 쓰는 courseTitle/unitTitle/streakDays와 정렬한다
 * (app/src/features/play/types.ts, app/src/features/home/types.ts 참조).
 *
 * <p>리스트 키가 {@code items}가 아닌 {@code courses}인 이유: 홈은 스트릭·포인트가 함께 담기는 복합
 * 응답이라 "응답의 주인공이 목록"이 아니다 — docs/api-standard.md §4의 예외 규칙을 따른다.
 */
public record HomeResponse(int streakDays, int points, boolean todayCompleted, List<CourseLearning> courses) {

    /** 학습 중인 코스 카드에 필요한 진입점 정보 — 정답을 맞히는 데 필요한 문제 본문은 담지 않는다(퀴즈 조회 API 몫). */
    @Schema(name = "HomeCourseItem")
    public record CourseLearning(
            Long courseId,
            String courseTitle,
            Long unitId,
            String unitTitle,
            int order,
            int completedCount,
            int totalCount,
            int estimatedMinutes) {

        /**
         * {@code minStepOrder}는 이 코스의 시작 스텝 번호다 — stepOrder가 코스 무관 전역 순번이라 항상 1은
         * 아니다(예: 디자인패턴 코스는 13부터 시작). "1을 빼면 완료 수"라는 가정은 첫 코스(1부터 시작)에만
         * 우연히 맞았을 뿐이라, 실제 시작 스텝을 받아 완료 수를 계산한다.
         */
        public static CourseLearning of(Course course, QuizStep current, int minStepOrder, int totalCount) {
            return new CourseLearning(
                    course.getId(),
                    course.getTitle(),
                    current.getId(),
                    current.getTopic(),
                    current.getStepOrder(),
                    current.getStepOrder() - minStepOrder,
                    totalCount,
                    current.getEstimatedMinutes());
        }
    }
}
