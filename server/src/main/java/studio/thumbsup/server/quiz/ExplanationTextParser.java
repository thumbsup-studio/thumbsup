package studio.thumbsup.server.quiz;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Set;

/**
 * 해설 본문에 저작된 {@code [[키워드]]} 마커를 "평문 + 하이라이트 구간"으로 번역한다.
 *
 * <p>저작 형식(마커)과 전송 형식(구간)을 나누는 이유: 키워드가 본문 어디에 있는지는 글을 쓴 쪽이
 * 이미 아는 정보다. 그 정보를 버리고 서버가 문자열 매칭으로 복원하면 한국어에는 단어 경계가 없어
 * 오탐이 난다 — 키워드 {@code 정렬}은 {@code 정렬되지 않은}의 {@code 정렬}에도 걸리고, 조사가
 * 붙으면({@code 스택은}) 경계를 잡을 수 없다. 그래서 위치는 저작 시점에 확정하고(#26), 서버는
 * 번역만 한다. 마커는 DB 저장 형식일 뿐 API 응답에는 노출되지 않는다.
 *
 * <p>보장하는 불변식 — FE는 방어 코드 없이 그대로 잘라 쓸 수 있다.
 *
 * <ul>
 *   <li>{@code start} 오름차순으로 정렬된다.
 *   <li>구간끼리 겹치지 않는다 (마커는 중첩될 수 없으므로 구조적으로 보장된다).
 *   <li>{@code 0 <= start < end <= text.length()}이고, {@code text.substring(start, end)}는 키워드와 같다.
 *   <li>오프셋 단위는 UTF-16 code unit이다 — Java {@code String}과 JS {@code String}이 같은 단위라
 *       FE가 {@code slice(start, end)}로 그대로 자를 수 있다.
 * </ul>
 *
 * <p>사전({@code quiz_keyword})에 없는 {@code [[...]]}는 마커로 보지 않고 리터럴 텍스트로 통과시킨다.
 * 덕분에 본문에 우연히 섞인 {@code [[ -z "$x" ]]} 같은 코드가 깨지지 않고, 마커 이스케이프 규칙을
 * 따로 발명할 필요도 없다. 대신 키워드에 오타가 있으면 조용히 하이라이트가 누락된다 — 그 검증은
 * 생성 파이프라인(#26)의 몫이다.
 */
public final class ExplanationTextParser {

    private static final String MARKER_OPEN = "[[";
    private static final String MARKER_CLOSE = "]]";

    /** 평문 기준 하이라이트 구간. {@code end}는 배타적이다. */
    public record Mark(String keyword, int start, int end) {}

    /** 마커가 제거된 평문과 그 평문을 가리키는 구간들. */
    public record Parsed(String text, List<Mark> marks) {}

    private ExplanationTextParser() {}

    /**
     * 개행으로 나뉜 본문을 줄 단위로 파싱한다 — "핵심 N줄 정리"(#8)용.
     * 각 구간의 오프셋은 전체 본문이 아니라 <b>그 줄의 {@code text}</b>를 기준으로 한다.
     * 빈 줄은 버린다. 줄을 나눈 뒤 파싱하므로 키워드가 줄바꿈에 걸치는 경우는 생기지 않는다.
     */
    public static List<Parsed> parseLines(String source, Set<String> knownKeywords) {
        if (source == null || source.isBlank()) {
            return List.of();
        }
        return Arrays.stream(source.split("\\R"))
                .map(String::strip)
                .filter(line -> !line.isEmpty())
                .map(line -> parse(line, knownKeywords))
                .toList();
    }

    /** 한 덩어리 본문을 파싱한다 — 예시·오답 해설처럼 줄을 나누지 않는 필드용. */
    public static Parsed parse(String source, Set<String> knownKeywords) {
        StringBuilder text = new StringBuilder(source.length());
        List<Mark> marks = new ArrayList<>();
        int cursor = 0;

        while (cursor < source.length()) {
            int open = source.indexOf(MARKER_OPEN, cursor);
            if (open < 0) {
                break;
            }
            int close = source.indexOf(MARKER_CLOSE, open + MARKER_OPEN.length());
            if (close < 0) {
                break; // 닫는 마커가 없으면 남은 전부가 리터럴이다
            }

            String keyword = source.substring(open + MARKER_OPEN.length(), close);
            int afterClose = close + MARKER_CLOSE.length();
            if (isMarker(keyword, knownKeywords)) {
                text.append(source, cursor, open);
                int start = text.length();
                text.append(keyword);
                marks.add(new Mark(keyword, start, text.length()));
            } else {
                // 마커가 아닌 [[...]]는 통째로 리터럴이다. 여는 괄호 뒤가 아니라 닫는 괄호 뒤로 건너뛰어야
                // 매 반복이 같은 구간을 다시 훑지 않는다 — "[[" 가 수천 개 섞인 본문에서 O(n^2)이 되는 걸 막는다.
                // 중첩 마커([[가상 [[메모리]]]])는 이 규칙에 따라 전체가 리터럴이 된다(중첩은 저작 규칙상 금지).
                text.append(source, cursor, afterClose);
            }
            cursor = afterClose;
        }

        text.append(source, cursor, source.length());
        return new Parsed(text.toString(), List.copyOf(marks));
    }

    /**
     * 빈 키워드를 마커로 인정하지 않는다 — {@code [[]]}가 {@code start == end}인 구간을 만들어
     * "잘라내면 키워드와 같다"는 불변식을 깨기 때문이다. {@code quiz_keyword.keyword}는 NOT NULL이지만
     * 빈 문자열을 막지 않으므로 데이터가 오염돼도 계약이 무너지지 않게 여기서 방어한다.
     */
    private static boolean isMarker(String keyword, Set<String> knownKeywords) {
        return !keyword.isEmpty() && knownKeywords.contains(keyword);
    }
}
