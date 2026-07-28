package studio.thumbsup.server.quiz;

import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;
import studio.thumbsup.server.quiz.dto.RetryHint;

/**
 * 오답 재도전 힌트(#63)를 만든다 — {@link QuizService#submitAnswer}에서 분리했다
 * (checkstyle 파일 길이 상한 400줄). 정답을 흘리지 않도록 부분 힌트만 준다: 사지선다는 오답 하나를
 * 소거하고, 빈칸은 슬롯별 첫 글자·글자수를 준다. 그 외에는 {@code null}이다.
 */
final class RetryHintBuilder {

    private RetryHintBuilder() {}

    /**
     * OX는 힌트로 줄 형태가 없어 유형으로도 막는다 — 현재 데이터에서 OX는 항상 EASY지만
     * 코드가 그 결합을 가정하지 않는다.
     */
    static RetryHint build(Quiz quiz, List<String> answers, boolean isCorrect) {
        if (isCorrect || quiz.getDifficulty() == QuizDifficulty.EASY || quiz.getType() == QuizType.OX) {
            return null;
        }
        if (quiz.getType() == QuizType.MULTIPLE_CHOICE) {
            return buildMultipleChoiceHint(quiz, answers);
        }
        return buildKeywordBlankHint(quiz);
    }

    /**
     * 사용자가 방금 고른 오답을 지우는 건 이미 아는 사실이라 힌트가 되지 않으므로, 오답 중 사용자가 고르지 않은
     * 것을 소거한다. 4지선다면 오답 3개 중 최소 2개가 후보라 항상 하나는 나온다. 표시 순서(displayOrder) 기준
     * 첫 번째를 골라 결정적으로 만든다 — 컬렉션의 {@code @OrderBy}에 기대지 않고 여기서 명시적으로 정렬한다.
     * 제출값이 파싱되지 않아 사용자 선택을 특정할 수 없으면 오답 중 첫 번째를 소거한다.
     */
    private static RetryHint buildMultipleChoiceHint(Quiz quiz, List<String> answers) {
        Long submittedChoiceId = parseChoiceId(answers.get(0));
        Long eliminatedChoiceId = quiz.getChoices().stream()
                .filter(choice -> !choice.isCorrect())
                .filter(choice -> !Objects.equals(choice.getId(), submittedChoiceId))
                .min(Comparator.comparingInt(QuizChoice::getDisplayOrder))
                .map(QuizChoice::getId)
                .orElse(null);
        if (eliminatedChoiceId == null) {
            return null;
        }
        return new RetryHint(eliminatedChoiceId, null);
    }

    /**
     * 슬롯마다 첫 키워드의 첫 글자와 공백 제외 글자수를 준다. "첫 키워드"는 그 슬롯에 등록된 순서(엔티티 id
     * 오름차순) 기준 첫 번째다 — 시드에서 한글 표기가 먼저, 영문 동의어가 뒤에 와서 자연스럽게 한글이 힌트가 된다.
     * 글자수는 정답 매칭이 띄어쓰기를 무시하므로(#183) 공백을 제외해 센다. 목록은 {@code slotOrder} 오름차순으로
     * 내려준다. 키워드가 등록되지 않은 문제는 힌트 없이({@code null}) 넘어간다.
     */
    private static RetryHint buildKeywordBlankHint(Quiz quiz) {
        Map<Integer, List<QuizAnswerKeyword>> keywordsBySlot =
                quiz.getAnswerKeywords().stream().collect(Collectors.groupingBy(QuizAnswerKeyword::getSlotOrder));
        if (keywordsBySlot.isEmpty()) {
            return null;
        }
        List<RetryHint.BlankHint> blankHints = keywordsBySlot.entrySet().stream()
                .sorted(Map.Entry.comparingByKey())
                .map(entry -> toBlankHint(entry.getKey(), entry.getValue()))
                .toList();
        return new RetryHint(null, blankHints);
    }

    private static RetryHint.BlankHint toBlankHint(int slotOrder, List<QuizAnswerKeyword> slotKeywords) {
        String keyword = slotKeywords.stream()
                .min(Comparator.comparing(QuizAnswerKeyword::getId))
                .map(QuizAnswerKeyword::getKeyword)
                .orElseThrow();
        String withoutWhitespace = QuizService.normalizeBlankAnswer(keyword);
        return new RetryHint.BlankHint(slotOrder, withoutWhitespace.substring(0, 1), withoutWhitespace.length());
    }

    private static Long parseChoiceId(String rawChoiceId) {
        try {
            return Long.valueOf(rawChoiceId);
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
