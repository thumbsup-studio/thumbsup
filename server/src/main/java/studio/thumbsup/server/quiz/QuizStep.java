package studio.thumbsup.server.quiz;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/**
 * 스텝(문제 5개 세트) 단위 주제 메타데이터(#26) — {@code quiz.quiz_step_id}가 이 행의 PK를 FK로 참조한다(#292).
 * 홈 화면 등에서 "이번 스텝: CPU 스케줄링 기초" 같은 표시에 쓰인다.
 *
 * <p>{@code stepOrder}는 코스 내 상대 순번이다(코스마다 1부터 시작) — {@code (courseId, stepOrder)}
 * 조합으로 유일하다. {@code courseId}는 다른 도메인 참조가 아니라 같은 quiz 슬라이스 내부 값이지만,
 * 조회가 항상 courseId로 먼저 필터링되는 패턴이라 JPA 연관관계 없이 DB FK만 둔다.
 */
@Getter
@Entity
@Table(name = "quiz_step")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizStep extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** 코스 내 상대 순번(1부터) — 전역으로는 유일하지 않다. 유일성은 {@code (courseId, stepOrder)}가 보장한다. */
    @Column(nullable = false)
    private int stepOrder;

    @Column(nullable = false)
    private Long courseId;

    @Column(nullable = false)
    private String topic;

    /** 홈 화면 "오늘의 학습" 카드에 표시하는 예상 소요 시간(분) — 원래 learning.Unit이 갖던 필드다(#117). */
    @Column(nullable = false)
    private int estimatedMinutes;

    private QuizStep(int stepOrder, Long courseId, String topic, int estimatedMinutes) {
        this.stepOrder = stepOrder;
        this.courseId = courseId;
        this.topic = topic;
        this.estimatedMinutes = estimatedMinutes;
    }

    public static QuizStep create(int stepOrder, Long courseId, String topic, int estimatedMinutes) {
        return new QuizStep(stepOrder, courseId, topic, estimatedMinutes);
    }
}
