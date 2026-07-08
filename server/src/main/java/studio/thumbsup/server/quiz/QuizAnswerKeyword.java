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

/** 빈칸 정답 키워드 — {@link QuizType#KEYWORD_BLANK}에서만 채워진다. 슬롯(빈칸)별로 여러 행. */
@Getter
@Entity
@Table(name = "quiz_answer_keyword")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizAnswerKeyword {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "quiz_id", nullable = false)
    private Quiz quiz;

    @Column(nullable = false)
    private int slotOrder;

    @Column(nullable = false, length = 200)
    private String keyword;

    QuizAnswerKeyword(Quiz quiz, int slotOrder, String keyword) {
        this.quiz = quiz;
        this.slotOrder = slotOrder;
        this.keyword = keyword;
    }

    static QuizAnswerKeyword create(Quiz quiz, int slotOrder, String keyword) {
        return new QuizAnswerKeyword(quiz, slotOrder, keyword);
    }
}
