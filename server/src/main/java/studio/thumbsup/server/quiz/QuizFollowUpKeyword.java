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

/**
 * 꼬리질문 본문 속 키워드 툴팁 설명.
 *
 * <p>부모 문제의 {@link QuizKeyword}와 분리한다 — 꼬리질문은 부모 문제에 없던 개념을 끌어오기 때문이다
 * (스택 문제의 꼬리질문에 등장하는 FIFO처럼).
 */
@Getter
@Entity
@Table(name = "quiz_follow_up_keyword")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizFollowUpKeyword {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "follow_up_question_id", nullable = false)
    private QuizFollowUpQuestion followUpQuestion;

    @Column(nullable = false, length = 200)
    private String keyword;

    @Column(nullable = false, length = 1000)
    private String description;

    QuizFollowUpKeyword(QuizFollowUpQuestion followUpQuestion, String keyword, String description) {
        this.followUpQuestion = followUpQuestion;
        this.keyword = keyword;
        this.description = description;
    }

    static QuizFollowUpKeyword create(QuizFollowUpQuestion followUpQuestion, String keyword, String description) {
        return new QuizFollowUpKeyword(followUpQuestion, keyword, description);
    }
}
