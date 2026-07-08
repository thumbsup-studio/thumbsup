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

/** 파생개념 — 지식그래프 연결(#21)은 향후 확장, 지금은 개념 이름만 저장한다. */
@Getter
@Entity
@Table(name = "quiz_derived_concept")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizDerivedConcept {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "quiz_id", nullable = false)
    private Quiz quiz;

    @Column(nullable = false, length = 200)
    private String name;

    @Column(nullable = false)
    private int displayOrder;

    QuizDerivedConcept(Quiz quiz, String name, int displayOrder) {
        this.quiz = quiz;
        this.name = name;
        this.displayOrder = displayOrder;
    }

    static QuizDerivedConcept create(Quiz quiz, String name, int displayOrder) {
        return new QuizDerivedConcept(quiz, name, displayOrder);
    }
}
