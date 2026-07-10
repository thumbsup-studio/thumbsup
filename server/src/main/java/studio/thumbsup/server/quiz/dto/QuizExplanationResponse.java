package studio.thumbsup.server.quiz.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import studio.thumbsup.server.quiz.ExplanationTextParser;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizFollowUpQuestion;
import studio.thumbsup.server.quiz.QuizKeyword;
import studio.thumbsup.server.quiz.QuizType;

/**
 * "해설 조회" 응답 — 해설 화면(S4)이 문제 정보와 해설을 함께 그리는 데 필요한 콘텐츠를 담는다.
 *
 * <p>채점 결과(isCorrect)와 정답은 담지 않는다. 해설은 quizId만으로 정해지는 정적 콘텐츠라
 * 채점 이벤트와 무관하고, 여기에 정답 여부를 실으면 이 조회가 정답 제출(#42)이 쓴 행을 읽어야 해서
 * 순서에 묶인다. 정답 여부는 채점 주체인 {@link AnswerSubmitResponse}가 반환한다.
 */
@Schema(description = "문제 정보와 해설 — 문제 맥락, 핵심 정리, 예시, 오답 해설, 키워드 툴팁, 꼬리질문")
public record QuizExplanationResponse(
        Long quizId,

        @Schema(description = "문제 본문") String questionText,

        @Schema(description = "문제 유형") QuizType type,

        @Schema(description = "문제 난이도") QuizDifficulty difficulty,

        @Schema(description = "현재 스텝 내 문제 순번", example = "1")
        int currentNumber,

        @Schema(description = "현재 스텝에 실제 저장된 전체 문제 수", example = "5")
        long totalCount,

        @Schema(description = "대주제 제목. MVP 기본 Course의 제목") String courseTitle,

        @Schema(description = "소주제 제목. QuizStep의 주제(topic)") String unitTitle,

        @Schema(description = "핵심 N줄 정리 — 저장된 본문을 개행으로 나눈 줄 목록")
        List<AnnotatedText> explanationSummary,

        @Schema(description = "적용 예시. 없을 수 있다") AnnotatedText explanationExample,

        @Schema(description = "오답 해설 — 정답/오답과 무관하게 항상 내려간다. 표시 여부는 FE가 정한다")
        AnnotatedText wrongAnswerExplanation,

        @Schema(description = "키워드 툴팁 사전. highlights의 keyword로 이 목록을 조회한다")
        List<KeywordItem> keywords,

        @Schema(description = "꼬리질문 — 대표 질문이 맨 앞에 온다") List<String> followUpQuestions) {

    /** 마커가 제거된 평문과, 그 평문 안에서 키워드가 차지하는 구간. */
    @Schema(description = "평문과 그 안의 키워드 하이라이트 구간")
    public record AnnotatedText(
            @Schema(description = "마커가 제거된 본문") String text,
            @Schema(description = "start 오름차순 · 서로 겹치지 않음") List<Highlight> highlights) {

        static AnnotatedText from(ExplanationTextParser.Parsed parsed) {
            return new AnnotatedText(
                    parsed.text(), parsed.marks().stream().map(Highlight::from).toList());
        }
    }

    /**
     * {@code text.substring(start, end)}가 곧 {@code keyword}다.
     * 오프셋 단위는 UTF-16 code unit — JS에서 {@code text.slice(start, end)}로 그대로 자를 수 있다.
     */
    @Schema(description = "하이라이트 구간. 오프셋은 text 기준 UTF-16 code unit, end는 배타적")
    public record Highlight(String keyword, int start, int end) {

        static Highlight from(ExplanationTextParser.Mark mark) {
            return new Highlight(mark.keyword(), mark.start(), mark.end());
        }
    }

    @Schema(description = "키워드와 툴팁에 띄울 설명")
    public record KeywordItem(String keyword, String description) {

        static KeywordItem from(QuizKeyword keyword) {
            return new KeywordItem(keyword.getKeyword(), keyword.getDescription());
        }
    }

    /**
     * 대표 질문(isPrimary)을 맨 앞에 두고 나머지는 저작 순서를 따른다.
     * 엔티티의 {@code @OrderBy}는 DB에서 읽을 때만 적용되므로, 응답 순서는 여기서 확정한다.
     */
    private static final Comparator<QuizFollowUpQuestion> PRIMARY_FIRST = Comparator.comparing(
                    QuizFollowUpQuestion::isPrimary, Comparator.reverseOrder())
            .thenComparingInt(QuizFollowUpQuestion::getDisplayOrder);

    public static QuizExplanationResponse from(Quiz quiz, long totalCount, String courseTitle, String unitTitle) {
        Set<String> knownKeywords =
                quiz.getKeywords().stream().map(QuizKeyword::getKeyword).collect(Collectors.toSet());

        return new QuizExplanationResponse(
                quiz.getId(),
                quiz.getQuestionText(),
                quiz.getType(),
                quiz.getDifficulty(),
                quiz.getSlotOrder(),
                totalCount,
                courseTitle,
                unitTitle,
                ExplanationTextParser.parseLines(quiz.getExplanationSummary(), knownKeywords).stream()
                        .map(AnnotatedText::from)
                        .toList(),
                annotate(quiz.getExplanationExample(), knownKeywords),
                annotate(quiz.getWrongAnswerExplanation(), knownKeywords),
                quiz.getKeywords().stream().map(KeywordItem::from).toList(),
                quiz.getFollowUpQuestions().stream()
                        .sorted(PRIMARY_FIRST)
                        .map(QuizFollowUpQuestion::getContent)
                        .toList());
    }

    private static AnnotatedText annotate(String source, Set<String> knownKeywords) {
        return source == null ? null : AnnotatedText.from(ExplanationTextParser.parse(source, knownKeywords));
    }
}
