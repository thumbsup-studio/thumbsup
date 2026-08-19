package studio.thumbsup.server.quiz.generation;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

/** 생성한 스텝 브리핑의 길이·순서·표시 가능한 형태를 검증한다. */
final class GeneratedStepBriefingValidator {

    private static final int MIN_BLOCKS = 2;
    private static final int MAX_BLOCKS = 4;
    private static final int MAX_SUMMARY_LENGTH = 500;
    private static final int MAX_HEADING_LENGTH = 100;
    private static final int MAX_CONTENT_LENGTH = 2000;

    private GeneratedStepBriefingValidator() {}

    static void validate(GeneratedQuizSet.GeneratedBriefing briefing) {
        if (briefing == null) {
            throw new QuizGenerationException("스텝 브리핑이 비어 있습니다.");
        }
        requireLength("브리핑", "summary", briefing.summary(), MAX_SUMMARY_LENGTH);
        List<GeneratedQuizSet.GeneratedBriefingBlock> blocks = briefing.blocks();
        if (blocks == null || blocks.size() < MIN_BLOCKS || blocks.size() > MAX_BLOCKS) {
            throw new QuizGenerationException("브리핑 blocks는 %d~%d개여야 합니다.".formatted(MIN_BLOCKS, MAX_BLOCKS));
        }
        Set<String> headings = new HashSet<>();
        for (int index = 0; index < blocks.size(); index++) {
            GeneratedQuizSet.GeneratedBriefingBlock block = blocks.get(index);
            String location = "브리핑 blocks[%d]".formatted(index + 1);
            if (block == null || block.type() == null) {
                throw new QuizGenerationException("%s의 type이 비어 있습니다.".formatted(location));
            }
            requireLength(location, "heading", block.heading(), MAX_HEADING_LENGTH);
            requireLength(location, "content", block.content(), MAX_CONTENT_LENGTH);
            if (!headings.add(block.heading().trim().toLowerCase(java.util.Locale.ROOT))) {
                throw new QuizGenerationException("브리핑 block heading이 중복됩니다: %s".formatted(block.heading()));
            }
        }
    }

    private static void requireLength(String location, String field, String value, int maxLength) {
        if (value == null || value.isBlank()) {
            throw new QuizGenerationException("%s의 %s이 비어 있습니다.".formatted(location, field));
        }
        if (value.trim().length() > maxLength) {
            throw new QuizGenerationException("%s의 %s은 %d자 이하여야 합니다.".formatted(location, field, maxLength));
        }
    }
}
