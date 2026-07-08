package studio.thumbsup.server.quiz;

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
 * 유저의 퀴즈 풀이 이력 — 한 유저는 같은 퀴즈를 한 번만 풀 수 있다(DB 유니크 제약).
 *
 * <p>{@code userId}는 다른 도메인(auth)의 참조라 연관관계가 아니라 ID 값으로만 둔다
 * (server/docs/dto-and-query-patterns.md #2). {@code quiz}는 같은 도메인이라 연관관계를 사용한다.
 */
@Getter
@Entity
@Table(name = "quiz_attempt")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizAttempt extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "quiz_id", nullable = false)
    private Quiz quiz;

    @Column(nullable = false)
    private Long userId;

    @Column(nullable = false)
    private boolean isCorrect;

    private QuizAttempt(Quiz quiz, Long userId, boolean isCorrect) {
        this.quiz = quiz;
        this.userId = userId;
        this.isCorrect = isCorrect;
    }

    public static QuizAttempt create(Quiz quiz, Long userId, boolean isCorrect) {
        return new QuizAttempt(quiz, userId, isCorrect);
    }
}
