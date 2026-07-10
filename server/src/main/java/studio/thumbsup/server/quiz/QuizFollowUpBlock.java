package studio.thumbsup.server.quiz;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
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

/** 꼬리질문 화면의 "상세 정리" 블록 한 칸 — 라벨(예: 해설, 실무 사용처)과 본문을 갖는다. */
@Getter
@Entity
@Table(name = "quiz_follow_up_block")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class QuizFollowUpBlock {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "follow_up_question_id", nullable = false)
    private QuizFollowUpQuestion followUpQuestion;

    @Column(nullable = false, length = 50)
    private String label;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private FollowUpBlockType type;

    /** {@code [[키워드]]} 마커가 저작된 본문. 응답에서는 평문 + 하이라이트 구간으로 번역된다. */
    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(nullable = false)
    private int displayOrder;

    QuizFollowUpBlock(
            QuizFollowUpQuestion followUpQuestion,
            String label,
            FollowUpBlockType type,
            String content,
            int displayOrder) {
        this.followUpQuestion = followUpQuestion;
        this.label = label;
        this.type = type;
        this.content = content;
        this.displayOrder = displayOrder;
    }

    static QuizFollowUpBlock create(
            QuizFollowUpQuestion followUpQuestion,
            String label,
            FollowUpBlockType type,
            String content,
            int displayOrder) {
        return new QuizFollowUpBlock(followUpQuestion, label, type, content, displayOrder);
    }
}
