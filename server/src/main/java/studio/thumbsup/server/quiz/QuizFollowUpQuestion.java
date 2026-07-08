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

/** 꼬리질문 — {@code isPrimary}인 한 건이 해설 화면 하단 대표 질문(#9)으로 노출된다. */
@Getter
@Entity
@Table(name = "quiz_follow_up_question")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizFollowUpQuestion {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "quiz_id", nullable = false)
    private Quiz quiz;

    @Column(nullable = false, length = 500)
    private String content;

    @Column(nullable = false)
    private boolean isPrimary;

    @Column(nullable = false)
    private int displayOrder;

    QuizFollowUpQuestion(Quiz quiz, String content, boolean isPrimary, int displayOrder) {
        this.quiz = quiz;
        this.content = content;
        this.isPrimary = isPrimary;
        this.displayOrder = displayOrder;
    }

    static QuizFollowUpQuestion create(Quiz quiz, String content, boolean isPrimary, int displayOrder) {
        return new QuizFollowUpQuestion(quiz, content, isPrimary, displayOrder);
    }
}
