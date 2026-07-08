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

/** 사지선다 선택지 — {@link QuizType#MULTIPLE_CHOICE}에서만 채워진다. */
@Getter
@Entity
@Table(name = "quiz_choice")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizChoice {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "quiz_id", nullable = false)
    private Quiz quiz;

    @Column(nullable = false, length = 500)
    private String content;

    @Column(nullable = false)
    private boolean isCorrect;

    @Column(nullable = false)
    private int displayOrder;

    QuizChoice(Quiz quiz, String content, boolean isCorrect, int displayOrder) {
        this.quiz = quiz;
        this.content = content;
        this.isCorrect = isCorrect;
        this.displayOrder = displayOrder;
    }

    static QuizChoice create(Quiz quiz, String content, boolean isCorrect, int displayOrder) {
        return new QuizChoice(quiz, content, isCorrect, displayOrder);
    }
}
