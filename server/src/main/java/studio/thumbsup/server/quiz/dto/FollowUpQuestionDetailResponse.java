package studio.thumbsup.server.quiz.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import studio.thumbsup.server.quiz.ExplanationTextParser;
import studio.thumbsup.server.quiz.FollowUpBlockType;
import studio.thumbsup.server.quiz.QuizDifficulty;
import studio.thumbsup.server.quiz.QuizFollowUpBlock;
import studio.thumbsup.server.quiz.QuizFollowUpKeyword;
import studio.thumbsup.server.quiz.QuizFollowUpQuestion;

/**
 * "꼬리질문 상세" 응답 — 꼬리질문 화면이 그리는 콘텐츠 전부를 담는다.
 *
 * <p>세션 진행도(3/5·진행바)는 담지 않는다. 꼬리질문 화면은 세션 흐름 밖의 곁가지라 진행을 바꾸지 않고,
 * FE가 앞선 화면에서 받은 값을 그대로 들고 온다.
 *
 * <p>중첩 record가 {@link QuizExplanationResponse}와 모양이 같지만 공유하지 않는다 — API별 DTO 원칙
 * (docs/dto-and-query-patterns.md §1). 한쪽 화면의 요구가 바뀌어도 다른 쪽 계약이 끌려가지 않는다.
 */
@Schema(description = "꼬리질문 상세 — 출처 문제, 난이도, 질문, 한 줄 답, 상세 정리 블록, 키워드 툴팁")
public record FollowUpQuestionDetailResponse(
        Long followUpQuestionId,
        @Schema(description = "이 꼬리질문이 달린 출처 문제의 ID") Long sourceQuizId,

        @Schema(description = "출처 문제의 스텝 내 순번 — \"3번 문제에서 이어짐\"의 3", example = "3")
        int sourceQuizNumber,

        @Schema(description = "꼬리질문 자체의 난이도. 출처 문제의 난이도와 무관하다")
        QuizDifficulty difficulty,

        @Schema(description = "질문 본문. 마커가 없는 평문이다") String question,
        @Schema(description = "한 줄 답") AnnotatedText oneLineAnswer,

        @Schema(description = "상세 정리 — 항목 수와 라벨은 꼬리질문마다 다르다. 표시 순서대로 내려간다")
        List<DetailBlock> blocks,

        @Schema(description = "키워드 툴팁 사전. highlights의 keyword로 이 목록을 조회한다")
        List<KeywordItem> keywords) {

    /**
     * 마커가 제거된 평문과, 그 평문 안에서 키워드가 차지하는 구간.
     *
     * <p>{@code name}을 지정하는 이유: springdoc은 스키마 이름을 단순 클래스명으로 짓는다. 해설 응답에도
     * 같은 이름의 중첩 record가 있어, 이름을 나누지 않으면 두 스키마가 하나로 병합돼 한쪽 변경이 다른 쪽
     * 명세를 조용히 오염시킨다. Swagger는 FE 계약의 정본이다(docs/api-standard.md §1).
     */
    @Schema(name = "FollowUpAnnotatedText", description = "평문과 그 안의 키워드 하이라이트 구간")
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
    @Schema(name = "FollowUpHighlight", description = "하이라이트 구간. 오프셋은 text 기준 UTF-16 code unit, end는 배타적")
    public record Highlight(String keyword, int start, int end) {

        static Highlight from(ExplanationTextParser.Mark mark) {
            return new Highlight(mark.keyword(), mark.start(), mark.end());
        }
    }

    @Schema(description = "상세 정리 블록 한 칸")
    public record DetailBlock(
            @Schema(description = "블록 제목", example = "실무 사용처")
            String label,

            @Schema(description = "블록 종류") FollowUpBlockType type,
            AnnotatedText content) {

        static DetailBlock from(QuizFollowUpBlock block, Set<String> knownKeywords) {
            return new DetailBlock(
                    block.getLabel(),
                    block.getType(),
                    AnnotatedText.from(ExplanationTextParser.parse(block.getContent(), knownKeywords)));
        }
    }

    @Schema(name = "FollowUpKeywordItem", description = "키워드와 툴팁에 띄울 설명")
    public record KeywordItem(String keyword, String description) {

        static KeywordItem from(QuizFollowUpKeyword keyword) {
            return new KeywordItem(keyword.getKeyword(), keyword.getDescription());
        }
    }

    /** 상세가 저작된 꼬리질문만 넘어온다 — 호출 전에 {@code hasDetail()}로 걸러진다. */
    public static FollowUpQuestionDetailResponse from(QuizFollowUpQuestion followUpQuestion) {
        Set<String> knownKeywords = followUpQuestion.getKeywords().stream()
                .map(QuizFollowUpKeyword::getKeyword)
                .collect(Collectors.toSet());

        return new FollowUpQuestionDetailResponse(
                followUpQuestion.getId(),
                followUpQuestion.getQuiz().getId(),
                followUpQuestion.getQuiz().getSlotOrder(),
                followUpQuestion.getDifficulty(),
                followUpQuestion.getContent(),
                AnnotatedText.from(ExplanationTextParser.parse(followUpQuestion.getOneLineAnswer(), knownKeywords)),
                followUpQuestion.getBlocks().stream()
                        .map(block -> DetailBlock.from(block, knownKeywords))
                        .toList(),
                followUpQuestion.getKeywords().stream().map(KeywordItem::from).toList());
    }
}
