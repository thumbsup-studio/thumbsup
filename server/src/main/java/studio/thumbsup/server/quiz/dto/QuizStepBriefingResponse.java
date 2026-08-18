package studio.thumbsup.server.quiz.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepBriefing;
import studio.thumbsup.server.quiz.QuizStepBriefingBlock;
import studio.thumbsup.server.quiz.QuizStepBriefingBlockType;

/** 현재 풀이할 스텝을 소개하는 읽기 전용 응답. */
@Schema(description = "문제 풀이 전 스텝 개념 브리핑")
public record QuizStepBriefingResponse(
        @Schema(description = "브리핑 대상 스텝의 영구 식별자", example = "42")
        Long quizStepId,

        @Schema(description = "소속 코스 식별자", example = "1") Long courseId,

        @Schema(description = "코스 내 스텝 표시 순서", example = "4")
        int stepOrder,

        @Schema(description = "스텝 주제", example = "CPU 스케줄링") String topic,
        @Schema(description = "한 문장 핵심 요약") String summary,
        @Schema(description = "순서대로 읽는 개념 설명 블록") List<Block> blocks) {

    public static QuizStepBriefingResponse from(QuizStep step, QuizStepBriefing briefing) {
        return new QuizStepBriefingResponse(
                step.getId(),
                step.getCourseId(),
                step.getStepOrder(),
                step.getTopic(),
                briefing.getSummary(),
                briefing.getBlocks().stream().map(Block::from).toList());
    }

    @Schema(name = "QuizStepBriefingBlockResponse", description = "스텝 브리핑의 설명 블록")
    public record Block(
            @Schema(description = "블록 성격", example = "CONCEPT")
            QuizStepBriefingBlockType type,

            @Schema(description = "짧은 소제목", example = "스케줄링이 필요한 이유")
            String heading,

            @Schema(description = "설명 본문") String content,
            @Schema(description = "표시 순서", example = "1") int displayOrder) {

        private static Block from(QuizStepBriefingBlock block) {
            return new Block(block.getType(), block.getHeading(), block.getContent(), block.getDisplayOrder());
        }
    }
}
