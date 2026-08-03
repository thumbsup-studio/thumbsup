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
 * 유저의 퀴즈 풀이 시도 이력 — 복습을 위해 같은 유저·퀴즈 조합도 여러 번 기록될 수 있다.
 * "이미 통과했는지"는 이 이력 중 {@code isCorrect=true}인 시도가 있는지로 판단한다.
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

    /** 제출한 답 원본(쉼표로 이어붙인 값) — #261, 풀이 기록 열람(#191)용. 이 필드 도입 이전 시도는 null. */
    @Column(name = "selected_answer", columnDefinition = "TEXT")
    private String selectedAnswer;

    private QuizAttempt(Quiz quiz, Long userId, boolean isCorrect, String selectedAnswer) {
        this.quiz = quiz;
        this.userId = userId;
        this.isCorrect = isCorrect;
        this.selectedAnswer = selectedAnswer;
    }

    public static QuizAttempt create(Quiz quiz, Long userId, boolean isCorrect) {
        return new QuizAttempt(quiz, userId, isCorrect, null);
    }

    public static QuizAttempt create(Quiz quiz, Long userId, boolean isCorrect, String selectedAnswer) {
        return new QuizAttempt(quiz, userId, isCorrect, selectedAnswer);
    }
}
