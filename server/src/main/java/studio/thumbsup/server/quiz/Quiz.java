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

    /** 정답 제출 전에 사용자가 요청해 보는 한 문장 힌트. 정답·선택지 라벨을 직접 노출하지 않는다(#193). */
    @Column(columnDefinition = "TEXT")
    private String hint;

    /** OX 전용 정답("O"/"X"). 사지선다·빈칸은 자식 테이블로 정답을 표현한다. */
    @Column(length = 10)
    private String correctAnswer;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String explanationSummary;

    @Column(columnDefinition = "TEXT")
    private String explanationExample;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String wrongAnswerExplanation;

    /** 이 문제가 속한 스텝의 PK(#292) — 실제 참조 무결성은 이 컬럼이 담당한다. */
    @Column(nullable = false)
    private Long quizStepId;

    /**
     * 코스 내 상대 순번(1부터, #292) — {@link QuizStep#getStepOrder()}를 그대로 복사해 둔 비정규화
     * 캐시다. 조회 편의를 위해 quiz_step까지 조인하지 않고 바로 읽을 수 있게 두지만, 정합성은
     * {@link #quizStepId}가 보장하므로 이 값을 단독으로 식별자처럼 쓰지 않는다(코스마다 값이 겹친다).
     */
    @Column(nullable = false)
    private int stepOrder;

    /** 스텝 내 출제 순서(1~5) — 같은 난이도가 2개씩 있어 순서 구분이 필요하다. */
    @Column(nullable = false)
    private int slotOrder;

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

    /** 저작 순서를 응답 순서로 삼는다 — 해설 API의 키워드 사전이 결정적으로 내려가야 한다(#43). */
    @OneToMany(mappedBy = "quiz", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("id ASC")
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

    /** 생성·백필 검증을 마친 한 문장 힌트를 지정한다. */
    public void assignHint(String hint) {
        this.hint = hint;
    }

    /** 커리큘럼 내 위치를 지정한다 — 콘텐츠 필드와 분리해 생성자 파라미터 수를 제한한다(checkstyle). */
    public void assignPosition(Long quizStepId, int stepOrder, int slotOrder) {
        this.quizStepId = quizStepId;
        this.stepOrder = stepOrder;
        this.slotOrder = slotOrder;
    }

    /**
     * 저작 개선(#174) 승인 시 본문 필드를 교체한다. {@code type}/{@code difficulty}/{@code quizStepId}/
     * {@code stepOrder}/{@code slotOrder}는 절대 바꾸지 않는다 — 개선은 같은 슬롯의 내용만 다듬는 것이지
     * 문제를 재배치하지 않는다.
     */
    public void updateContent(
            String questionText,
            String codeSnippet,
            String hint,
            String explanationSummary,
            String explanationExample,
            String wrongAnswerExplanation) {
        this.questionText = questionText;
        this.codeSnippet = codeSnippet;
        this.hint = hint;
        this.explanationSummary = explanationSummary;
        this.explanationExample = explanationExample;
        this.wrongAnswerExplanation = wrongAnswerExplanation;
    }

    /**
     * 자식 콘텐츠를 전부 비운다 — 개선 승인이 {@link #updateContent} 다음에 호출해 자식을 다시 채울
     * 자리를 만든다. {@code orphanRemoval = true}라 비운 자식은 flush 시 실제로 삭제된다.
     */
    public void resetForRepopulation() {
        this.correctAnswer = null;
        choices.clear();
        answerKeywords.clear();
        followUpQuestions.clear();
        derivedConcepts.clear();
        keywords.clear();
    }

    public void addChoice(String content, boolean isCorrect, int displayOrder) {
        choices.add(QuizChoice.create(this, content, isCorrect, displayOrder));
    }

    public void addAnswerKeyword(int slotOrder, String keyword) {
        answerKeywords.add(QuizAnswerKeyword.create(this, slotOrder, keyword));
    }

    /** 생성된 꼬리질문을 돌려준다 — 상세 콘텐츠(난이도·한 줄 답·블록·키워드)를 이어서 붙일 수 있도록. */
    public QuizFollowUpQuestion addFollowUpQuestion(String content, boolean isPrimary, int displayOrder) {
        QuizFollowUpQuestion followUpQuestion = QuizFollowUpQuestion.create(this, content, isPrimary, displayOrder);
        followUpQuestions.add(followUpQuestion);
        return followUpQuestion;
    }

    public void addDerivedConcept(String name, int displayOrder) {
        derivedConcepts.add(QuizDerivedConcept.create(this, name, displayOrder));
    }

    public void addKeyword(String keyword, String description) {
        keywords.add(QuizKeyword.create(this, keyword, description));
    }
}
