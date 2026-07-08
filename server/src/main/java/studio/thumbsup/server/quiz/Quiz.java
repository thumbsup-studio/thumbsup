package studio.thumbsup.server.quiz;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import java.util.ArrayList;
import java.util.List;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/**
 * 퀴즈 엔티티 — 문제 세트의 aggregate root.
 *
 * <p>선택지·정답 키워드·꼬리질문·파생개념·키워드 설명은 문제 유형({@link QuizType})에 따라
 * 일부만 채워진다 — 예: OX는 {@link #choices}가 비어 있고 {@link #correctAnswer}만 쓴다.
 * 생성은 정적 팩토리 {@link #create}로 공통 필드를 채운 뒤, {@code addXxx}/{@link #assignCorrectAnswer}로
 * 유형별 데이터를 채운다. 사전 생성된 콘텐츠라 이후 부분 수정 없이 세트 단위로 저장된다.
 */
@Getter
@Entity
@Table(name = "quiz")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Quiz extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private QuizType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private QuizDifficulty difficulty;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String questionText;

    @Column(columnDefinition = "TEXT")
    private String codeSnippet;

    /** OX 전용 정답("O"/"X"). 사지선다·빈칸은 자식 테이블로 정답을 표현한다. */
    @Column(length = 10)
    private String correctAnswer;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String explanationSummary;

    @Column(columnDefinition = "TEXT")
    private String explanationExample;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String wrongAnswerExplanation;

    @OneToMany(mappedBy = "quiz", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("displayOrder ASC")
    private List<QuizChoice> choices = new ArrayList<>();

    @OneToMany(mappedBy = "quiz", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("slotOrder ASC")
    private List<QuizAnswerKeyword> answerKeywords = new ArrayList<>();

    @OneToMany(mappedBy = "quiz", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("displayOrder ASC")
    private List<QuizFollowUpQuestion> followUpQuestions = new ArrayList<>();

    @OneToMany(mappedBy = "quiz", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("displayOrder ASC")
    private List<QuizDerivedConcept> derivedConcepts = new ArrayList<>();

    @OneToMany(mappedBy = "quiz", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<QuizKeyword> keywords = new ArrayList<>();

    private Quiz(
            QuizType type,
            QuizDifficulty difficulty,
            String questionText,
            String codeSnippet,
            String explanationSummary,
            String explanationExample,
            String wrongAnswerExplanation) {
        this.type = type;
        this.difficulty = difficulty;
        this.questionText = questionText;
        this.codeSnippet = codeSnippet;
        this.explanationSummary = explanationSummary;
        this.explanationExample = explanationExample;
        this.wrongAnswerExplanation = wrongAnswerExplanation;
    }

    public static Quiz create(
            QuizType type,
            QuizDifficulty difficulty,
            String questionText,
            String codeSnippet,
            String explanationSummary,
            String explanationExample,
            String wrongAnswerExplanation) {
        return new Quiz(
                type,
                difficulty,
                questionText,
                codeSnippet,
                explanationSummary,
                explanationExample,
                wrongAnswerExplanation);
    }

    /** OX 전용 — 정답을 "O" 또는 "X"로 지정한다. */
    public void assignCorrectAnswer(String correctAnswer) {
        this.correctAnswer = correctAnswer;
    }

    public void addChoice(String content, boolean isCorrect, int displayOrder) {
        choices.add(QuizChoice.create(this, content, isCorrect, displayOrder));
    }

    public void addAnswerKeyword(int slotOrder, String keyword) {
        answerKeywords.add(QuizAnswerKeyword.create(this, slotOrder, keyword));
    }

    public void addFollowUpQuestion(String content, boolean isPrimary, int displayOrder) {
        followUpQuestions.add(QuizFollowUpQuestion.create(this, content, isPrimary, displayOrder));
    }

    public void addDerivedConcept(String name, int displayOrder) {
        derivedConcepts.add(QuizDerivedConcept.create(this, name, displayOrder));
    }

    public void addKeyword(String keyword, String description) {
        keywords.add(QuizKeyword.create(this, keyword, description));
    }
}
