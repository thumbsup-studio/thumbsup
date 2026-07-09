package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import studio.thumbsup.server.quiz.ExplanationTextParser.Mark;
import studio.thumbsup.server.quiz.ExplanationTextParser.Parsed;

/**
 * 마커 파싱 규칙을 전수 검증한다 (피라미드 1층 — Spring 없음).
 * 인수 테스트는 "시드가 하이라이트로 변환된다"만 확인하고, 분기·경계는 전부 여기서 흡수한다.
 */
@DisplayName("해설 마커 파서")
class ExplanationTextParserTest {

    private static final Set<String> KEYWORDS = Set.of("연결 지향", "3-way handshake", "스택");

    @Nested
    @DisplayName("한 덩어리 본문 파싱")
    class ParseSingleText {

        @Test
        @DisplayName("마커를 제거하고 남은 평문을 기준으로 구간을 매긴다")
        void strips_markers_and_anchors_offsets() {
            Parsed parsed = ExplanationTextParser.parse("TCP는 [[연결 지향]] 프로토콜이다.", KEYWORDS);

            assertThat(parsed.text()).isEqualTo("TCP는 연결 지향 프로토콜이다.");
            assertThat(parsed.marks()).containsExactly(new Mark("연결 지향", 5, 10));
            assertThat(parsed.text().substring(5, 10)).isEqualTo("연결 지향");
        }

        @Test
        @DisplayName("마커가 없으면 평문을 그대로 두고 구간은 비어 있다")
        void returns_source_as_is_when_no_marker() {
            Parsed parsed = ExplanationTextParser.parse("마커가 없는 문장이다.", KEYWORDS);

            assertThat(parsed.text()).isEqualTo("마커가 없는 문장이다.");
            assertThat(parsed.marks()).isEmpty();
        }

        @Test
        @DisplayName("키워드 사전에 없는 마커는 리터럴 텍스트로 통과시킨다")
        void keeps_unknown_marker_as_literal() {
            String source = "셸에서는 [[ -z \"$x\" ]] 로 빈 문자열을 확인한다.";

            Parsed parsed = ExplanationTextParser.parse(source, KEYWORDS);

            assertThat(parsed.text()).isEqualTo(source);
            assertThat(parsed.marks()).isEmpty();
        }

        @Test
        @DisplayName("닫는 마커가 없으면 남은 본문을 리터럴로 둔다")
        void keeps_unclosed_marker_as_literal() {
            Parsed parsed = ExplanationTextParser.parse("[[연결 지향 프로토콜", KEYWORDS);

            assertThat(parsed.text()).isEqualTo("[[연결 지향 프로토콜");
            assertThat(parsed.marks()).isEmpty();
        }

        @Test
        @DisplayName("같은 키워드를 두 번 마킹하면 구간도 두 개 나온다")
        void marks_every_authored_occurrence() {
            Parsed parsed = ExplanationTextParser.parse("[[스택]]과 또 다른 [[스택]]", Set.of("스택"));

            assertThat(parsed.text()).isEqualTo("스택과 또 다른 스택");
            assertThat(parsed.marks()).containsExactly(new Mark("스택", 0, 2), new Mark("스택", 9, 11));
        }

        @Test
        @DisplayName("중첩 마커는 전체가 리터럴이 된다 — 중첩은 저작 규칙상 금지다")
        void keeps_nested_marker_as_literal() {
            Parsed parsed = ExplanationTextParser.parse("[[가상 [[스택]]]]", KEYWORDS);

            assertThat(parsed.text()).isEqualTo("[[가상 [[스택]]]]");
            assertThat(parsed.marks()).isEmpty();
        }

        @Test
        @DisplayName("빈 키워드는 마커로 보지 않는다 — 폭 0짜리 구간이 생기면 안 된다")
        void never_produces_zero_width_mark() {
            Parsed parsed = ExplanationTextParser.parse("값은 [[]] [[스택]]", Set.of("", "스택"));

            assertThat(parsed.text()).isEqualTo("값은 [[]] 스택");
            assertThat(parsed.marks()).containsExactly(new Mark("스택", 8, 10));
            assertThat(parsed.marks())
                    .allSatisfy(mark -> assertThat(mark.start()).isLessThan(mark.end()));
        }

        @Test
        @DisplayName("이모지가 섞여도 오프셋은 UTF-16 code unit 기준이다 — JS의 slice와 같은 단위")
        void offsets_are_utf16_code_units() {
            Parsed parsed = ExplanationTextParser.parse("🚀 [[스택]]", KEYWORDS);

            assertThat(parsed.text()).isEqualTo("🚀 스택");
            assertThat(parsed.marks()).containsExactly(new Mark("스택", 3, 5));
            assertThat(parsed.text().substring(3, 5)).isEqualTo("스택");
        }

        @Test
        @DisplayName("구간은 start 오름차순이고 서로 겹치지 않으며, 잘라내면 키워드와 같다")
        void marks_are_sorted_disjoint_and_anchored() {
            Parsed parsed = ExplanationTextParser.parse("[[스택]]과 [[연결 지향]]", KEYWORDS);

            List<Mark> marks = parsed.marks();
            assertThat(marks).hasSize(2);
            assertThat(marks.get(0).end()).isLessThanOrEqualTo(marks.get(1).start());
            for (Mark mark : marks) {
                assertThat(parsed.text().substring(mark.start(), mark.end())).isEqualTo(mark.keyword());
            }
        }
    }

    @Nested
    @DisplayName("개행으로 나뉜 본문 파싱")
    class ParseLines {

        @Test
        @DisplayName("개행마다 줄을 나누고 구간은 각 줄을 기준으로 매긴다")
        void splits_by_newline_and_anchors_per_line() {
            List<Parsed> lines = ExplanationTextParser.parseLines("첫 줄이다.\nTCP는 [[연결 지향]]이다.", KEYWORDS);

            assertThat(lines).hasSize(2);
            assertThat(lines.get(0).marks()).isEmpty();
            assertThat(lines.get(1).text()).isEqualTo("TCP는 연결 지향이다.");
            assertThat(lines.get(1).marks()).containsExactly(new Mark("연결 지향", 5, 10));
        }

        @Test
        @DisplayName("빈 줄을 버리고 줄 앞뒤 공백을 다듬는다")
        void drops_blank_lines_and_trims() {
            List<Parsed> lines = ExplanationTextParser.parseLines("첫 줄이다.  \n\n  둘째 줄이다.\n", KEYWORDS);

            assertThat(lines).extracting(Parsed::text).containsExactly("첫 줄이다.", "둘째 줄이다.");
        }

        @Test
        @DisplayName("본문이 비어 있으면 빈 목록을 반환한다")
        void returns_empty_list_for_blank_source() {
            assertThat(ExplanationTextParser.parseLines("   ", KEYWORDS)).isEmpty();
            assertThat(ExplanationTextParser.parseLines(null, KEYWORDS)).isEmpty();
        }
    }
}
