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
 * 스텝(문제 5개 세트) 단위 주제 메타데이터(#26) — {@code quiz.step_order}가 FK로 참조한다.
 * 홈 화면 등에서 "이번 스텝: CPU 스케줄링 기초" 같은 표시에 쓰인다.
 *
 * <p>{@code stepOrder}는 코스와 무관하게 전역 유일 순번이다(코스별로 다시 세지 않는다) — {@code courseId}는
 * 그 위에 붙는 소속 태그일 뿐이다. {@code courseId}는 {@code quiz.step_order}가 {@link #stepOrder}를
 * 참조하는 것과 같은 스타일로 DB FK만 두고 JPA 연관관계는 쓰지 않는다.
 */
@Getter
@Entity
@Table(name = "quiz_step")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizStep extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true)
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
