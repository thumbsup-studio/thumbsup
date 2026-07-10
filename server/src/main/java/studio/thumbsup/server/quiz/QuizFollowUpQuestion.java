package studio.thumbsup.server.quiz;

import jakarta.persistence.CascadeType;
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
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import java.util.ArrayList;
import java.util.List;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 꼬리질문 — {@code isPrimary}인 한 건이 해설 화면 하단 대표 질문(#9)으로 노출된다.
 *
 * <p>탭하면 열리는 꼬리질문 화면은 <b>새 문제를 푸는 화면이 아니다.</b> 풀이·채점이 없고 질문·한 줄 답·
 * 상세 정리만 읽는다. 그래서 꼬리질문은 다른 문제를 가리키지 않고 스스로 콘텐츠를 갖는다(#108).
 *
 * <p>기존 생성물(#26)은 질문 텍스트만 갖고 있어 상세 필드가 비어 있다. 상세가 없는 꼬리질문은
 * 화면에 그릴 것이 없으므로 해설 응답에서 제외된다 — {@link #hasDetail()}.
 */
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

    /** 꼬리질문 자체의 난이도 — 부모 문제의 난이도와 무관하다. 상세가 없으면 null. */
    @Enumerated(EnumType.STRING)
    @Column(length = 10)
    private QuizDifficulty difficulty;

    /** {@code [[키워드]]} 마커가 저작된 "한 줄 답". 상세가 없으면 null. */
    @Column(length = 500)
    private String oneLineAnswer;

    @OneToMany(mappedBy = "followUpQuestion", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("displayOrder ASC")
    private List<QuizFollowUpBlock> blocks = new ArrayList<>();

    /** 저작 순서를 응답 순서로 삼는다 — 키워드 사전이 결정적으로 내려가야 한다(#43과 동일). */
    @OneToMany(mappedBy = "followUpQuestion", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("id ASC")
    private List<QuizFollowUpKeyword> keywords = new ArrayList<>();

    QuizFollowUpQuestion(Quiz quiz, String content, boolean isPrimary, int displayOrder) {
        this.quiz = quiz;
        this.content = content;
        this.isPrimary = isPrimary;
        this.displayOrder = displayOrder;
    }

    static QuizFollowUpQuestion create(Quiz quiz, String content, boolean isPrimary, int displayOrder) {
        return new QuizFollowUpQuestion(quiz, content, isPrimary, displayOrder);
    }

    /**
     * 꼬리질문 화면을 그릴 수 있는가. 블록은 없어도 화면이 성립하지만 한 줄 답은 필수다.
     *
     * <p>한쪽만 봐도 되는 이유: 난이도와 한 줄 답은 {@link #attachDetail}로 함께 채워지고,
     * DB 제약({@code ck_quiz_follow_up_question_detail})이 "둘 다 있거나 둘 다 없거나"를 강제한다.
     * 생성 파이프라인(#26)이 raw SQL로 백필하더라도 이 불변식은 깨지지 않는다.
     */
    public boolean hasDetail() {
        return oneLineAnswer != null;
    }

    /** 상세 콘텐츠를 붙인다 — 난이도와 한 줄 답은 항상 짝으로 존재한다. */
    public void attachDetail(QuizDifficulty difficulty, String oneLineAnswer) {
        this.difficulty = difficulty;
        this.oneLineAnswer = oneLineAnswer;
    }

    public void addBlock(String label, FollowUpBlockType type, String content, int displayOrder) {
        blocks.add(QuizFollowUpBlock.create(this, label, type, content, displayOrder));
    }

    public void addKeyword(String keyword, String description) {
        keywords.add(QuizFollowUpKeyword.create(this, keyword, description));
    }
}
