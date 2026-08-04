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
            int estimatedMinutes,
            boolean completed) {

        /**
         * {@code completedCount}는 정렬된 코스 스텝 목록에서 현재 스텝 앞에 있는 스텝 수다 — stepOrder는
         * 코스 무관 전역 순번인 데다 중간 스텝 삭제로 코스 안에서도 비연속일 수 있어(예: 1, 3만 남은 코스),
         * 번호 뺄셈으로는 완료 수를 구할 수 없다. 목록 인덱스는 호출부(HomeService)가 계산해 넘긴다.
         *
         * <p>{@code completed}는 완주 여부다 — 완주 시 커서가 마지막 스텝으로 클램프되면
         * completedCount만으로는 "마지막 스텝 풀 차례"와 완주를 구분할 수 없어 별도 필드로 내린다.
         */
        public static CourseLearning of(
                Course course, QuizStep current, int completedCount, int totalCount, boolean completed) {
            return new CourseLearning(
                    course.getId(),
                    course.getTitle(),
                    current.getId(),
                    current.getTopic(),
                    current.getStepOrder(),
                    completedCount,
                    totalCount,
                    current.getEstimatedMinutes(),
                    completed);
        }
    }
}
