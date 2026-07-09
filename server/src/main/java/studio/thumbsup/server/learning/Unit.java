package studio.thumbsup.server.learning;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/**
 * 코스 내 화(에피소드) 엔티티 — 커리큘럼 목차의 한 항목. {@code orderIndex}는 코스 내 1-based 순번이다.
 * 같은 도메인(learning) 내부 참조라 {@link Course}와 {@code @ManyToOne} 연관관계를 사용한다.
 *
 * <p>{@code UnitRepository}로 직접 조회되므로(Course 하위 컬렉션 전용 조회에 그치지 않음) 감사 필드가
 * 붙는 최상위 엔티티({@code QuizAttempt}·{@code QuizProgress})와 같은 패턴을 따라 BaseEntity를 상속한다.
 */
@Getter
@Entity
@Table(name = "unit")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Unit extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "course_id", nullable = false)
    private Course course;

    @Column(nullable = false)
    private int orderIndex;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(nullable = false)
    private int estimatedMinutes;

    Unit(Course course, int orderIndex, String title, int estimatedMinutes) {
        this.course = course;
        this.orderIndex = orderIndex;
        this.title = title;
        this.estimatedMinutes = estimatedMinutes;
    }

    static Unit create(Course course, int orderIndex, String title, int estimatedMinutes) {
        return new Unit(course, orderIndex, title, estimatedMinutes);
    }
}
