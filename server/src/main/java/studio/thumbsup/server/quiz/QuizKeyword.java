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

/** 지문 속 키워드 툴팁 설명 — 해설 화면 인라인 툴팁(#12)에 쓰인다. */
@Getter
@Entity
@Table(name = "quiz_keyword")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizKeyword {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "quiz_id", nullable = false)
    private Quiz quiz;

    @Column(nullable = false, length = 200)
    private String keyword;

    @Column(nullable = false, length = 1000)
    private String description;

    QuizKeyword(Quiz quiz, String keyword, String description) {
        this.quiz = quiz;
        this.keyword = keyword;
        this.description = description;
    }

    static QuizKeyword create(Quiz quiz, String keyword, String description) {
        return new QuizKeyword(quiz, keyword, description);
    }
}
