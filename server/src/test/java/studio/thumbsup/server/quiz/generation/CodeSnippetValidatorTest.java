package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

class CodeSnippetValidatorTest {

    @Nested
    @DisplayName("코드 지문 검증")
    class ValidateCodeSnippet {

        @Test
        @DisplayName("codeSnippet이 null이면 코드 지문이 없는 정상 문제로 허용한다")
        void accepts_null_snippet() {
            assertThatCode(() -> CodeSnippetValidator.validate("슬롯 4", null)).doesNotThrowAnyException();
        }

        @ParameterizedTest(name = "{0}")
        @MethodSource("validCodeSnippets")
        @DisplayName("현행 코드와 명시적 의사코드 지문은 허용한다")
        void accepts_code_and_explicit_pseudocode(String description, String codeSnippet) {
            assertThatCode(() -> CodeSnippetValidator.validate("슬롯 4", codeSnippet))
                    .doesNotThrowAnyException();
        }

        @ParameterizedTest(name = "{0}")
        @MethodSource("invalidCodeSnippets")
        @DisplayName("코드 구조가 없는 값은 거부한다")
        void rejects_values_without_code_structure(String description, String codeSnippet) {
            assertThatThrownBy(() -> CodeSnippetValidator.validate("슬롯 4", codeSnippet))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("codeSnippet");
        }

        @Test
        @DisplayName("지나치게 긴 한 줄은 정규식 검사 전에 거부한다")
        void rejects_an_excessively_long_line() {
            assertThatThrownBy(() -> CodeSnippetValidator.validate("슬롯 4", "a".repeat(501)))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("지나치게 긴 줄");
        }

        @Test
        @DisplayName("앞 공백을 제거하기 전에 원본 줄 길이를 검사한다")
        void rejects_an_excessively_long_line_before_stripping() {
            String codeSnippet = " ".repeat(501) + "dispatch(process)";

            assertThatThrownBy(() -> CodeSnippetValidator.validate("슬롯 4", codeSnippet))
                    .isInstanceOf(QuizGenerationException.class)
                    .hasMessageContaining("지나치게 긴 줄");
        }

        private static Stream<Arguments> validCodeSnippets() {
            return Stream.of(
                            Stream.of(
                                    Arguments.of("C 코드", """
                            int fd = open("data.txt", O_RDONLY);
                            char buf[16];
                            read(fd, buf, sizeof(buf));
                            """),
                                    Arguments.of("C 계산 선언", "int total = left + right;"),
                                    Arguments.of("Python 코드", """
                            start = inode.indexBlock
                            for i in range(fileBlockCount):
                                dataBlock = read(start[i])
                                process(dataBlock)
                            """),
                                    Arguments.of("Python 반환문", """
                            def choose():
                                return result
                            """),
                                    Arguments.of("Python 조건문", """
                            if priority < bestPriority:
                                select(process)
                            """),
                                    Arguments.of("Python truthiness 조건문", """
                            if ready:
                                dispatch(process)
                            """),
                                    Arguments.of("명시적 의사코드", """
                            semaphore s = 1;

                            wait(s);
                            // critical section
                            signal(s);
                            """),
                                    Arguments.of("소문자 명시적 의사코드", """
                            if ready then
                                dispatch(process)
                            end if
                            """),
                                    Arguments.of("SQL 코드", """
                            SELECT process_id, priority
                            FROM ready_queue
                            ORDER BY priority ASC;
                            """),
                                    Arguments.of("셸 파이프라인", "echo hello | grep h")),
                            validFunctionCallSnippets(),
                            validParenthesizedControlSnippets())
                    .flatMap(stream -> stream);
        }

        private static Stream<Arguments> validFunctionCallSnippets() {
            return Stream.of(
                    Arguments.of("C 호출 선언", "int result = calculate();"),
                    Arguments.of("C 함수 선언", "int calculate(int left, int right);"),
                    Arguments.of("JavaScript 호출 선언", "const result = fetch();"),
                    Arguments.of("연속 함수 호출", "push(1); push(2); pop(); // 결과: ?"));
        }

        private static Stream<Arguments> validParenthesizedControlSnippets() {
            return Stream.of(
                    Arguments.of("C truthiness 조건문", "if (ready) {"),
                    Arguments.of("C 비교 조건문", "if (priority < bestPriority) {"),
                    Arguments.of("C 복합 조건문", "if (!ready || queue.isEmpty()) {"),
                    Arguments.of("C 함수 호출 조건문", "while (read(fd, buf, size) > 0) {"),
                    Arguments.of("C for 반복문", "for (int i = 0; i < count; i++) {"),
                    Arguments.of(
                            "운영 시드의 한 줄 이중 for 반복문",
                            "for (int i = 0; i < n; i++) { for (int j = 0; j < n; j++) { ... } }"),
                    Arguments.of("Java enhanced for 반복문", "for (Process process : readyQueue) {"),
                    Arguments.of("JavaScript for-of 반복문", "for (const item of items) {"),
                    Arguments.of("Java catch 문", "catch (IOException e) {"));
        }

        private static Stream<Arguments> invalidCodeSnippets() {
            return Stream.of(
                            Stream.of(
                                    Arguments.of("빈 문자열", ""),
                                    Arguments.of("공백 문자열", " \n\t"),
                                    Arguments.of("주석만 있는 지문", """
                            // 단일 CPU 환경 가정
                            # 각 숫자는 페이지 번호를 의미한다.
                            """),
                                    Arguments.of("Step 2 Slot 4 자연어 시나리오", """
                            // 단일 CPU 환경 가정
                            프로세스 P가 현재 CPU에서 실행 중이다.
                            타이머 인터럽트가 발생했고,
                            운영체제는 P의 실행 정보를 저장한 뒤
                            다른 프로세스에게 CPU를 넘긴다.
                            """),
                                    Arguments.of("Step 4 Slot 4 구조화 자연어", """
                            프로세스: P1(우선순위 3), P2(우선순위 1), P3(우선순위 2)
                            가정: 숫자가 작을수록 우선순위가 높고, 모두 같은 시각에 준비 상태가 된다.
                            스케줄링: 비선점형 우선순위 스케줄링
                            """),
                                    Arguments.of("Step 5 Slot 4 조건 목록", """
                            Process A: priority=3, burst=5
                            Process B: priority=1, burst=8
                            Process C: priority=2, burst=2
                            Process D: priority=4, burst=1
                            """),
                                    Arguments.of("대입문으로 표현한 조건 목록", """
                            priority = 3
                            burst = 5
                            """),
                                    Arguments.of("선언처럼 보이는 상태 조건", "Process state = READY"),
                                    Arguments.of("리터럴 정수 선언", "int age = 20;"),
                                    Arguments.of("리터럴 문자열 선언", "const name = \"Alice\";"),
                                    Arguments.of("Step 10 Slot 4 입력 데이터", """
                            references = [1, 2, 3, 2, 4]
                            frames = 3
                            # 각 숫자는 페이지 번호를 의미한다.
                            """),
                                    Arguments.of("자연어에 코드 한 줄을 섞은 지문", """
                            준비된 프로세스를 실행한다.
                            dispatch(process)
                            """)),
                            invalidNaturalCommandSnippets(),
                            invalidControlSnippets(),
                            invalidCallSnippets())
                    .flatMap(stream -> stream);
        }

        private static Stream<Arguments> invalidNaturalCommandSnippets() {
            return Stream.of(
                    Arguments.of("Return으로 시작하는 영어 자연어", "Return the process with the highest priority."),
                    Arguments.of("Select로 시작하는 영어 자연어", "Select the process with the highest priority."),
                    Arguments.of("Find로 시작하는 영어 자연어", "Find the process with the shortest burst time."));
        }

        private static Stream<Arguments> invalidControlSnippets() {
            return Stream.of(
                    Arguments.of("자연어 if 조건", "if the input is valid:"),
                    Arguments.of("자연어 for 조건", "for each item:"),
                    Arguments.of("괄호로 감싼 영어 자연어 if 조건", "if (the input is not valid)"),
                    Arguments.of("괄호로 감싼 한국어 자연어 if 조건", "if (사용자가 로그인하지 않은 경우)"),
                    Arguments.of("대문자 제어문으로 위장한 자연어", "IF (the input is not valid)"),
                    Arguments.of("물음표를 포함한 한국어 자연어 if 조건", "if (입력이 유효한가?)"),
                    Arguments.of("콜론을 포함한 영어 자연어 if 조건", "if (input: valid)"),
                    Arguments.of("세미콜론으로 위장한 자연어 for 조건", "for (each item; do something; continue)"),
                    Arguments.of("소문자 타입처럼 보이는 자연어 catch 조건", "catch (the error)"));
        }

        private static Stream<Arguments> invalidCallSnippets() {
            return Stream.of(
                    Arguments.of("함수 호출처럼 보이는 자연어", "note (the input is valid)"),
                    Arguments.of("중첩 호출처럼 보이는 자연어", "note(wrapper(the input is valid))"),
                    Arguments.of("호출 인자에 섞인 자연어", "note(first, the input is valid)"),
                    Arguments.of("정상 호출 뒤에 섞인 자연어", "dispatch(process); note(the input is valid)"),
                    Arguments.of("인덱스에 숨긴 영어 자연어", "note(items[the input is valid])"),
                    Arguments.of("인덱스에 숨긴 한국어 자연어", "note(items[사용자가 로그인한 경우])"),
                    Arguments.of("대입식 호출에 숨긴 자연어", "result = note(the input is valid)"),
                    Arguments.of("선언식 호출에 숨긴 자연어", "int result = note(the input is valid);"),
                    Arguments.of("Python 조건 호출에 숨긴 자연어", "if note(the input is valid):"),
                    Arguments.of("return 호출에 숨긴 자연어", "return note(the input is valid);"),
                    Arguments.of("대입식 인덱스에 숨긴 자연어", "result = items[the input is valid]"),
                    Arguments.of("함수 선언 파라미터로 위장한 자연어", "int note(the input is valid);"),
                    Arguments.of("한 줄 함수 본문에 숨긴 자연어", "void f() { note(the input is valid); }"),
                    Arguments.of("대입식에서 제어문 이름으로 위장한 자연어", "result = if(the input is valid)"),
                    Arguments.of("return에서 catch 이름으로 위장한 자연어", "return catch(the error);"),
                    Arguments.of("닫히지 않은 인덱스에 숨긴 자연어", "return items[the input is valid;"),
                    Arguments.of("열리지 않은 닫는 대괄호", "result = items] + value"),
                    Arguments.of("generic 타입 인자에 숨긴 자연어", "int f(List<note(the input is valid)> value);"),
                    Arguments.of("닫히지 않은 문자열에 숨긴 자연어", "int result = \"note(the input is valid);"));
        }
    }
}
