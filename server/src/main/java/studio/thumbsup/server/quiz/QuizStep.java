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
    private String topic;

    /** 홈 화면 "오늘의 학습" 카드에 표시하는 예상 소요 시간(분) — 원래 learning.Unit이 갖던 필드다(#117). */
    @Column(nullable = false)
    private int estimatedMinutes;

    private QuizStep(int stepOrder, String topic, int estimatedMinutes) {
        this.stepOrder = stepOrder;
        this.topic = topic;
        this.estimatedMinutes = estimatedMinutes;
    }

    public static QuizStep create(int stepOrder, String topic, int estimatedMinutes) {
        return new QuizStep(stepOrder, topic, estimatedMinutes);
    }
}
