package studio.thumbsup.server.quiz.generation;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 저작 시점에 심는 {@code [[키워드]]} 마커의 규칙을 검증한다 — 괄호 짝, 사전과의 정확 일치(오타 검출),
 * 한 필드 안에서의 중복 마킹 금지, 등록 키워드의 커버리지.
 *
 * <p>조회 API(#43·#108)는 사전에 없는 {@code [[...]]}를 예외 없이 리터럴 텍스트로 통과시킨다. 즉 오타는
 * 조용한 하이라이트 누락이 되고 아무도 알아채지 못한다. 저장 전에 여기서 막는 이유다.
 *
 * <p>사전이 무엇이냐는 호출자가 정한다 — 해설 본문은 문제의 {@code quiz_keyword}를, 꼬리질문은 그
 * 꼬리질문의 {@code quiz_follow_up_keyword}를 쓴다(#133). 그래서 사전을 인자로 받는다.
 */
final class KeywordMarkerValidator {

    private static final Pattern MARKER_PATTERN = Pattern.compile("\\[\\[([^\\[\\]]*)]]");

    private KeywordMarkerValidator() {}

    /**
     * 한 필드의 마커를 검증하고, 그 필드에서 마킹된 키워드 집합을 돌려준다.
     *
     * <p>이 메서드는 필드 내부 중복까지만 판단한다. 여러 필드 전체에서 정확히 한 번인지 확인해야 하는 호출자는
     * 반환된 집합을 표시 우선순위대로 합치면서 필드 간 중복과 최종 커버리지를 별도로 검증한다.
     */
    static Set<String> validateField(String location, String field, String text, Set<String> registeredKeywords) {
        Set<String> seenInField = new HashSet<>();
        for (String marker : extractMarkers(location, field, text)) {
            if (!registeredKeywords.contains(marker)) {
                throw new QuizGenerationException(
                        "%s의 %s에 keywords에 없는 마커가 있습니다(오타 의심): [[%s]]".formatted(location, field, marker));
            }
            if (!seenInField.add(marker)) {
                throw new QuizGenerationException(
                        "%s의 %s에서 같은 키워드가 두 번 이상 마킹됐습니다(첫 등장만 허용): [[%s]]".formatted(location, field, marker));
            }
        }
        return seenInField;
    }

    /** 평문으로 그대로 내려가는 필드(문제 본문·꼬리질문 본문)에 마커가 섞이지 않았는지 확인한다. */
    static void requireNoMarker(String location, String field, String text) {
        List<String> markers = extractMarkers(location, field, text);
        if (!markers.isEmpty()) {
            throw new QuizGenerationException(
                    "%s의 %s에는 마커를 넣을 수 없습니다: [[%s]]".formatted(location, field, markers.get(0)));
        }
    }

    /** 등록해 놓고 어느 필드에도 마킹하지 않은 키워드를 찾는다 — 툴팁이 뜨지 않는 사전 항목이 된다. */
    static void requireAllCovered(String location, Set<String> registeredKeywords, Set<String> covered, String where) {
        Set<String> uncovered = new HashSet<>(registeredKeywords);
        uncovered.removeAll(covered);
        if (!uncovered.isEmpty()) {
            throw new QuizGenerationException("%s의 키워드가 %s 어디에도 마킹되지 않았습니다: %s".formatted(location, where, uncovered));
        }
    }

    private static List<String> extractMarkers(String location, String field, String text) {
        if (text == null) {
            return List.of();
        }
        List<String> markers = new ArrayList<>();
        Matcher matcher = MARKER_PATTERN.matcher(text);
        while (matcher.find()) {
            markers.add(matcher.group(1));
        }
        String withoutMarkers = MARKER_PATTERN.matcher(text).replaceAll("");
        if (withoutMarkers.contains("[[") || withoutMarkers.contains("]]")) {
            throw new QuizGenerationException("%s의 %s에 마커 괄호 짝이 맞지 않습니다.".formatted(location, field));
        }
        return markers;
    }
}
