package studio.thumbsup.server.quiz.generation;

import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** 생성된 코드 지문에 실제 코드 또는 명시적 의사코드의 구조가 있는지 확인한다. */
final class CodeSnippetValidator {

    private static final int MAX_CODE_LINE_LENGTH = 500;
    private static final String IDENTIFIER = "[A-Za-z_$][A-Za-z0-9_$]*";
    private static final String LITERAL =
            "(?:[-+]?\\d+(?:\\.\\d+)?|true|false|null|" + "\"(?:\\\\.|[^\"])*\"|'(?:\\\\.|[^'])*')";
    private static final String INDEX_ATOM = "(?:" + IDENTIFIER + "|" + LITERAL + ")";
    static final String INDEX_EXPRESSION = INDEX_ATOM + "(?:\\s*[+\\-*/%]\\s*" + INDEX_ATOM + ")*";
    static final String ACCESS = IDENTIFIER + "(?:(?:\\." + IDENTIFIER + ")|(?:\\[" + INDEX_EXPRESSION + "]))*";
    private static final String BINARY_OPERATOR = "(?:==|!=|<=|>=|&&|\\|\\||[<>&|+\\-*/%]|\\binstanceof\\b)";
    private static final String SIMPLE_OPERAND = "(?:[!~]?\\s*(?:" + ACCESS + "|" + LITERAL + "))";
    private static final String SIMPLE_EXPRESSION =
            SIMPLE_OPERAND + "(?:\\s*" + BINARY_OPERATOR + "\\s*" + SIMPLE_OPERAND + ")*";
    private static final String NESTED_CALL =
            ACCESS + "\\s*\\((?:" + SIMPLE_EXPRESSION + "(?:\\s*,\\s*" + SIMPLE_EXPRESSION + ")*)?\\)";
    private static final String CALL_OPERAND = "(?:" + NESTED_CALL + "|" + SIMPLE_OPERAND + ")";
    private static final String CALL_ARGUMENT =
            CALL_OPERAND + "(?:\\s*" + BINARY_OPERATOR + "\\s*" + CALL_OPERAND + ")*";
    private static final String CALL =
            ACCESS + "\\s*\\((?:" + CALL_ARGUMENT + "(?:\\s*,\\s*" + CALL_ARGUMENT + ")*)?\\)";
    private static final String NON_CONTROL_CALL = "(?!(?i:if|for|while|switch|catch|with)\\b)" + CALL;
    private static final String VALUE_REFERENCE = "(?:" + CALL + "|" + ACCESS + ")";
    private static final String OPERAND = "(?:[!~]?\\s*(?:" + VALUE_REFERENCE + "|" + LITERAL + "))";
    private static final String GENERIC_TYPE_ARGUMENT = "(?:\\?|[A-Za-z_$][A-Za-z0-9_$.]*(?:\\[\\])?)";
    private static final String GENERIC_TYPE_ARGUMENTS =
            "<\\s*" + GENERIC_TYPE_ARGUMENT + "(?:\\s*,\\s*" + GENERIC_TYPE_ARGUMENT + ")*\\s*>";
    private static final String CODE_TYPE =
            "(?:byte|short|int|long|float|double|char|boolean|bool|auto|var|String|size_t|semaphore|mutex|"
                    + "(?:[a-z_$][A-Za-z0-9_$]*\\.)*[A-Z][A-Za-z0-9_$]*(?:"
                    + GENERIC_TYPE_ARGUMENTS
                    + ")?(?:\\[\\])?)";
    private static final String FUNCTION_PARAMETER =
            "(?:(?:final\\s+)?" + CODE_TYPE + "\\s+[*&]*\\s*" + IDENTIFIER + "|void)";
    private static final String FUNCTION_PARAMETER_LIST =
            "(?:" + FUNCTION_PARAMETER + "(?:\\s*,\\s*" + FUNCTION_PARAMETER + ")*)?";
    static final String CALL_ARGUMENT_OR_STAR = "(?:\\*|" + CALL_ARGUMENT + ")";
    /** 선언 줄 끝 — 빈 본문 한 줄 표기({@code {}})까지 인정한다. 흔한 생성자·훅 메서드 관용구다. */
    private static final String DECLARATION_SUFFIX = "(?:\\{\\s*}|\\{|;)?\\s*$";

    /**
     * 리턴 타입을 {@link #CODE_TYPE}(기본형뿐 아니라 커스텀 대문자 타입도 포함)로 받는다 — 디자인패턴의
     * {@code getInstance()}/{@code create()}/{@code build()}처럼 자기 타입이나 생성 결과 타입을 반환하는
     * 메서드가 하드코딩된 기본형 목록에 없어서 거부되던 문제를 고친다.
     */
    private static final Pattern FUNCTION_DECLARATION_LINE =
            Pattern.compile("^\\s*(?:(?:public|private|protected|static|final|volatile|unsigned|signed|abstract)\\s+)*"
                    + "(?:void|"
                    + CODE_TYPE
                    + ")"
                    + "\\s+[*&]*\\s*"
                    + "[A-Za-z_$][A-Za-z0-9_$]*\\s*\\(\\s*"
                    + FUNCTION_PARAMETER_LIST
                    + "\\s*\\)\\s*"
                    + DECLARATION_SUFFIX);

    /** Java/C++ 스타일 클래스·인터페이스·열거형 선언 — 파이썬 스타일(콜론)은 기존 STRONG 목록에 이미 있다. */
    private static final Pattern CLASS_DECLARATION_LINE =
            Pattern.compile("^\\s*(?:(?:public|private|protected|abstract|final|static)\\s+)*"
                    + "(?:class|interface|enum|record|struct)\\s+[A-Za-z_$][A-Za-z0-9_$]*"
                    + "(?:"
                    + GENERIC_TYPE_ARGUMENTS
                    + ")?"
                    + "(?:\\s+extends\\s+[A-Za-z_$][A-Za-z0-9_$.]*(?:"
                    + GENERIC_TYPE_ARGUMENTS
                    + ")?)?"
                    + "(?:\\s+implements\\s+[A-Za-z_$][A-Za-z0-9_$.]*(?:"
                    + GENERIC_TYPE_ARGUMENTS
                    + ")?(?:\\s*,\\s*[A-Za-z_$][A-Za-z0-9_$.]*(?:"
                    + GENERIC_TYPE_ARGUMENTS
                    + ")?)*)?"
                    + "\\s*"
                    + DECLARATION_SUFFIX);

    /**
     * 생성자 선언 — 리턴 타입이 없어 {@link #FUNCTION_DECLARATION_LINE}에 안 걸린다. 일반 함수 호출문과
     * 구분하기 위해 접근 제어자를 하나 이상 요구한다(호출문은 제어자를 붙이지 않는다).
     */
    private static final Pattern CONSTRUCTOR_DECLARATION_LINE =
            Pattern.compile("^\\s*(?:public|private|protected)\\s+(?:(?:public|private|protected|final)\\s+)*"
                    + "[A-Za-z_$][A-Za-z0-9_$]*\\s*\\(\\s*"
                    + FUNCTION_PARAMETER_LIST
                    + "\\s*\\)\\s*"
                    + DECLARATION_SUFFIX);

    private static final Pattern CONDITION_CONTROL_PREFIX =
            Pattern.compile("^\\s*(?:if|while|switch|with)\\s*\\(", Pattern.CASE_INSENSITIVE);
    private static final Pattern FOR_CONTROL_PREFIX = Pattern.compile("^\\s*for\\s*\\(", Pattern.CASE_INSENSITIVE);
    private static final Pattern CONTROL_SUFFIX = Pattern.compile("^\\s*(?:\\{.*|:|;)?\\s*$");
    private static final Pattern CATCH_CONTROL_LINE = Pattern.compile("^\\s*catch\\s*\\(\\s*(?:"
            + IDENTIFIER
            + "|"
            + CODE_TYPE
            + "\\s+"
            + IDENTIFIER
            + ")\\s*\\)\\s*(?:\\{.*|:|;)?\\s*$");
    private static final Pattern CONDITION_EXPRESSION =
            Pattern.compile("^\\s*" + OPERAND + "(?:\\s*" + BINARY_OPERATOR + "\\s*" + OPERAND + ")*\\s*$");
    private static final Pattern TERNARY_EXPRESSION =
            Pattern.compile("^\\s*" + OPERAND + "\\s*\\?\\s*" + OPERAND + "\\s*:\\s*" + OPERAND + "\\s*$");
    private static final Pattern FOR_INITIALIZER = Pattern.compile(
            "^\\s*(?:(?:" + CODE_TYPE + "|const|let)\\s+" + IDENTIFIER + "|" + ACCESS + ")\\s*=\\s*\\S(?:.*\\S)?\\s*$");
    private static final Pattern FOR_UPDATE = Pattern.compile("^\\s*(?:"
            + ACCESS
            + "(?:\\+\\+|--)|(?:\\+\\+|--)"
            + ACCESS
            + "|"
            + ACCESS
            + "\\s*(?:=|\\+=|-=|\\*=|/=|%=)\\s*\\S(?:.*\\S)?|"
            + CALL
            + ")\\s*$");
    private static final Pattern JAVA_ENHANCED_FOR = Pattern.compile(
            "^\\s*(?:final\\s+)?" + CODE_TYPE + "\\s+" + IDENTIFIER + "\\s*:\\s*" + VALUE_REFERENCE + "\\s*$");
    private static final Pattern JAVASCRIPT_FOR_OF = Pattern.compile(
            "^\\s*(?:const|let|var)\\s+" + IDENTIFIER + "\\s+(?:of|in)\\s+" + VALUE_REFERENCE + "\\s*$");

    private static final Pattern FULL_LINE_COMMENT = Pattern.compile(
            "^\\s*(?://|/\\*|\\*|\\*/|#(?!\\s*(?:!|include|define|if|ifdef|ifndef|endif|pragma)\\b)).*$");

    /** 단독으로도 실행 구조를 입증하는 보수적 패턴 목록이다. */
    private static final List<Pattern> STRONG_CODE_LINE_PATTERNS = List.of(
            FUNCTION_DECLARATION_LINE,
            CLASS_DECLARATION_LINE,
            CONSTRUCTOR_DECLARATION_LINE,
            Pattern.compile("^\\s*(?:(?:(?:(?:public|private|protected|static|final|volatile|unsigned|signed)\\s+)*"
                    + CODE_TYPE
                    + "\\s+[*&]*\\s*[A-Za-z_$][A-Za-z0-9_$]*(?:\\s*\\[[^\\]]*])?)|"
                    + "(?:(?:const|let|var)\\s+[A-Za-z_$][A-Za-z0-9_$]*))\\s*=\\s*(?:"
                    + ".*[A-Za-z_$][A-Za-z0-9_$]*\\s*\\(.*|"
                    + ".*[A-Za-z_$][A-Za-z0-9_$]*(?:\\.[A-Za-z_$][A-Za-z0-9_$]*|\\[[^\\]]+]).*|"
                    + ".*\\S\\s*(?:\\+|-|\\*|/|%|&&|\\|\\||==|!=|<=|>=|<|>)\\s*\\S.*)"
                    + "\\s*;?(?:\\s*//.*)?$"),
            Pattern.compile("^\\s*[A-Za-z_$][A-Za-z0-9_$]*(?:(?:\\.[A-Za-z_$][A-Za-z0-9_$]*)|(?:\\[[^\\]]+]))*\\s*"
                    + "(?:=|:=|<-|←|\\+=|-=|\\*=|/=|%=)\\s*(?:"
                    + ".*[A-Za-z_$][A-Za-z0-9_$]*\\s*\\(.*|"
                    + ".*[A-Za-z_$][A-Za-z0-9_$]*(?:\\.[A-Za-z_$][A-Za-z0-9_$]*|\\[[^\\]]+]).*|"
                    + ".*\\S\\s*(?:\\+|-|\\*|/|%|&&|\\|\\||==|!=|<=|>=|<|>)\\s*\\S.*)\\s*;?(?:\\s*//.*)?$"),
            Pattern.compile("^\\s*" + NON_CONTROL_CALL + "(?:\\s*;\\s*" + NON_CONTROL_CALL + ")*\\s*;?(?:\\s*//.*)?$"),
            Pattern.compile("^\\s*for\\s+[A-Za-z_$][A-Za-z0-9_$]*\\s+in\\s+.+:\\s*$"),
            Pattern.compile("^\\s*(?:if|elif|while)\\s+(?:"
                    + "[A-Za-z_$][A-Za-z0-9_$]*|not\\s+[A-Za-z_$][A-Za-z0-9_$]*|"
                    + "[A-Za-z_$][A-Za-z0-9_$]*(?:(?:\\.[A-Za-z_$][A-Za-z0-9_$]*)|(?:\\[[^\\]]+]))+|"
                    + "[A-Za-z_$][A-Za-z0-9_$]*\\s*\\(.*\\)|"
                    + "[A-Za-z_$][A-Za-z0-9_$]*(?:(?:\\.[A-Za-z_$][A-Za-z0-9_$]*)|(?:\\[[^\\]]+]))*"
                    + "\\s*(?:==|!=|<=|>=|<|>|\\s+(?:not\\s+)?in\\s+)\\s*"
                    + "(?:[A-Za-z_$][A-Za-z0-9_$]*(?:(?:\\.[A-Za-z_$][A-Za-z0-9_$]*)|(?:\\[[^\\]]+]))*|"
                    + "[-+]?\\d+(?:\\.\\d+)?|true|false|null|None|True|False|\"[^\"]*\"|'[^']*')|"
                    + "[A-Za-z_$][A-Za-z0-9_$]*(?:(?:\\.[A-Za-z_$][A-Za-z0-9_$]*)|(?:\\[[^\\]]+]))*"
                    + "\\s+is\\s+(?:not\\s+)?(?:None|True|False))\\s*:\\s*$"),
            Pattern.compile("^\\s*def\\s+[A-Za-z_$][A-Za-z0-9_$]*\\s*\\([^)]*\\)" + "\\s*(?:->\\s*[^:]+)?\\s*:\\s*$"),
            Pattern.compile("^\\s*class\\s+[A-Za-z_$][A-Za-z0-9_$]*(?:\\([^)]*\\))?\\s*:\\s*$"),
            Pattern.compile("^\\s*(?:else|try|finally)\\s*(?:\\{|:)\\s*$"),
            Pattern.compile("^\\s*except(?:\\s+[A-Za-z_$][A-Za-z0-9_$]*"
                    + "(?:\\s+as\\s+[A-Za-z_$][A-Za-z0-9_$]*)?)?\\s*:\\s*$"),
            Pattern.compile("^\\s*do\\s*\\{\\s*$"),
            Pattern.compile("^\\s*return(?:\\s+(?:"
                    + "[A-Za-z_$][A-Za-z0-9_$]*(?:(?:\\.[A-Za-z_$][A-Za-z0-9_$]*)|(?:\\[[^\\]]+]))*|"
                    + "[-+]?\\d+(?:\\.\\d+)?|true|false|null|None|"
                    + "\"(?:\\\\.|[^\"])*\"|'(?:\\\\.|[^'])*'|"
                    + ".*(?:\\(|\\[|\\+|-|\\*|/|%|&&|\\|\\||==|!=|<=|>=|<|>).*))?\\s*;?\\s*$"),
            Pattern.compile(
                    "^\\s*(?:IF\\b.+\\bTHEN|ELSE|END\\s+IF|FOR\\b.+\\b(?:TO|IN)\\b.+|"
                            + "END\\s+FOR|WHILE\\b.+\\bDO|END\\s+WHILE|REPEAT|UNTIL\\b.+|BEGIN|END)"
                            + "\\s*;?\\s*$",
                    Pattern.CASE_INSENSITIVE),
            Pattern.compile(
                    "^\\s*(?:#(?:include|define|if|ifdef|ifndef|endif|pragma)\\b.*|"
                            + "import\\s+\\S+.*|from\\s+\\S+\\s+import\\s+\\S+.*)$",
                    Pattern.CASE_INSENSITIVE),
            Pattern.compile(
                    "^\\s*(?:[A-Za-z_$][A-Za-z0-9_$]*(?:\\+\\+|--)|" + "(?:\\+\\+|--)[A-Za-z_$][A-Za-z0-9_$]*)\\s*;?$"),
            Pattern.compile(
                    "^\\s*SELECT\\s+(?:DISTINCT\\s+)?(?:\\*|"
                            + "(?:[A-Za-z_$][A-Za-z0-9_$]*(?:\\.[A-Za-z_$][A-Za-z0-9_$]*)?|"
                            + "[A-Za-z_$][A-Za-z0-9_$]*\\([^)]*\\))(?:\\s+AS\\s+[A-Za-z_$][A-Za-z0-9_$]*)?)"
                            + "(?:\\s*,\\s*(?:[A-Za-z_$][A-Za-z0-9_$]*(?:\\.[A-Za-z_$][A-Za-z0-9_$]*)?|"
                            + "[A-Za-z_$][A-Za-z0-9_$]*\\([^)]*\\))(?:\\s+AS\\s+[A-Za-z_$][A-Za-z0-9_$]*)?)*"
                            + "\\s*;?\\s*$",
                    Pattern.CASE_INSENSITIVE),
            Pattern.compile(
                    "^\\s*(?:FROM|(?:(?:LEFT|RIGHT|INNER|OUTER)\\s+)?JOIN)\\s+"
                            + "[A-Za-z_$][A-Za-z0-9_$.]*(?:\\s+(?:AS\\s+)?[A-Za-z_$][A-Za-z0-9_$]*)?"
                            + "(?:\\s+ON\\s+.+)?\\s*;?\\s*$",
                    Pattern.CASE_INSENSITIVE),
            Pattern.compile(
                    "^\\s*(?:ORDER|GROUP)\\s+BY\\s+[A-Za-z_$][A-Za-z0-9_$.]*"
                            + "(?:\\s+(?:ASC|DESC))?(?:\\s*,\\s*[A-Za-z_$][A-Za-z0-9_$.]*"
                            + "(?:\\s+(?:ASC|DESC))?)*\\s*;?\\s*$",
                    Pattern.CASE_INSENSITIVE),
            Pattern.compile(
                    "^\\s*(?:WHERE|HAVING)\\s+.*(?:=|<>|!=|<=|>=|<|>|\\bIN\\s*\\(|"
                            + "\\bLIKE\\b|\\bIS\\s+(?:NOT\\s+)?NULL\\b).*$",
                    Pattern.CASE_INSENSITIVE),
            Pattern.compile(
                    "^\\s*(?:INSERT\\s+INTO|UPDATE\\s+\\S+\\s+SET|DELETE\\s+FROM|MERGE\\s+INTO)" + "\\b.*$",
                    Pattern.CASE_INSENSITIVE),
            Pattern.compile(
                    "^\\s*(?:CREATE|ALTER|DROP)\\s+(?:TABLE|INDEX|VIEW|SCHEMA|DATABASE)\\b.*$",
                    Pattern.CASE_INSENSITIVE),
            Pattern.compile("^\\s*(?:#!.*|(?:[A-Za-z_][A-Za-z0-9_]*=\\S+\\s+)*"
                    + "(?:echo|printf|grep|awk|sed|cat|find|ls|cd|pwd|mkdir|rm|cp|mv|curl|wget|docker|git|"
                    + "java|python3?|node|npm|pnpm|gradle|chmod|chown|ps|kill|sleep|head|tail|sort|uniq|wc)"
                    + "\\b.*(?:\\||&&|;|>>?|<<?).*)$"));

    /** 강한 실행 구조와 함께 있을 때만 코드의 보조 줄로 인정한다. */
    private static final List<Pattern> SUPPORTING_CODE_LINE_PATTERNS = List.of(
            Pattern.compile("^\\s*(?:(?:public|private|protected|static|final|volatile|unsigned|signed)\\s+)*"
                    + CODE_TYPE
                    + "\\s+[*&]*\\s*"
                    + "[A-Za-z_$][A-Za-z0-9_$]*(?:\\s*\\[[^\\]]*])?\\s*(?:=|;).*$"),
            Pattern.compile("^\\s*(?:const|let|var)\\s+[A-Za-z_$][A-Za-z0-9_$]*\\s*=\\s*\\S.*$"),
            Pattern.compile("^\\s*[A-Za-z_$][A-Za-z0-9_$]*(?:(?:\\.[A-Za-z_$][A-Za-z0-9_$]*)|(?:\\[[^\\]]+]))*\\s*"
                    + "(?:=|:=|<-|←|\\+=|-=|\\*=|/=|%=)\\s*\\S.*$"),
            Pattern.compile("^\\s*[{}]+[;,]?\\s*$"),
            Pattern.compile("^\\s*@[A-Za-z_$][A-Za-z0-9_$]*(?:\\([^)]*\\))?\\s*$"));

    private CodeSnippetValidator() {}

    static void validate(String location, String codeSnippet) {
        if (codeSnippet == null) {
            return;
        }
        List<String> significantLines = codeSnippet
                .lines()
                .map(line -> requireWithinLineLimit(location, line))
                .map(String::strip)
                .filter(line -> !line.isBlank())
                .filter(line -> !FULL_LINE_COMMENT.matcher(line).matches())
                .toList();
        boolean hasStrongStructure = significantLines.stream().anyMatch(CodeSnippetValidator::hasStrongStructure);
        boolean allLinesLookLikeCode = !significantLines.isEmpty()
                && significantLines.stream().allMatch(CodeSnippetValidator::looksLikeCodeLine);
        if (!hasStrongStructure || !allLinesLookLikeCode) {
            throw new QuizGenerationException("%s의 codeSnippet은 실제 코드 또는 명시적 의사코드 구조를 포함해야 합니다.".formatted(location));
        }
    }

    private static boolean hasStrongStructure(String line) {
        return isStructuredControlLine(line)
                || STRONG_CODE_LINE_PATTERNS.stream()
                        .anyMatch(pattern -> pattern.matcher(line).matches());
    }

    static boolean isStructuredControlLine(String line) {
        String condition = extractParenthesizedBody(line, CONDITION_CONTROL_PREFIX);
        if (condition != null) {
            return isStructuredCondition(condition);
        }
        String forBody = extractParenthesizedBody(line, FOR_CONTROL_PREFIX);
        if (forBody != null) {
            return isStructuredFor(forBody);
        }
        return CATCH_CONTROL_LINE.matcher(line).matches();
    }

    private static String extractParenthesizedBody(String line, Pattern prefix) {
        Matcher prefixMatcher = prefix.matcher(line);
        if (!prefixMatcher.find()) {
            return null;
        }
        int openingParenthesis = prefixMatcher.end() - 1;
        int closingParenthesis = CodeSnippetLineGuard.findClosingParenthesis(line, openingParenthesis);
        if (closingParenthesis < 0) {
            return null;
        }
        String suffix = line.substring(closingParenthesis + 1);
        return CONTROL_SUFFIX.matcher(suffix).matches()
                ? line.substring(openingParenthesis + 1, closingParenthesis)
                : null;
    }

    private static boolean isStructuredCondition(String condition) {
        return CONDITION_EXPRESSION.matcher(condition).matches()
                || TERNARY_EXPRESSION.matcher(condition).matches();
    }

    private static boolean isStructuredFor(String body) {
        String[] clauses = body.split(";", -1);
        if (clauses.length == 3) {
            return (clauses[0].isBlank() || FOR_INITIALIZER.matcher(clauses[0]).matches())
                    && (clauses[1].isBlank() || isStructuredCondition(clauses[1]))
                    && (clauses[2].isBlank() || FOR_UPDATE.matcher(clauses[2]).matches());
        }
        return JAVA_ENHANCED_FOR.matcher(body).matches()
                || JAVASCRIPT_FOR_OF.matcher(body).matches();
    }

    private static boolean looksLikeCodeLine(String line) {
        if (!CodeSnippetLineGuard.isValid(line)) {
            return false;
        }
        return hasStrongStructure(line)
                || SUPPORTING_CODE_LINE_PATTERNS.stream()
                        .anyMatch(pattern -> pattern.matcher(line).matches());
    }

    static boolean isFunctionDeclarationLine(String line) {
        return FUNCTION_DECLARATION_LINE.matcher(line).matches();
    }

    private static String requireWithinLineLimit(String location, String line) {
        if (line.length() > MAX_CODE_LINE_LENGTH) {
            throw new QuizGenerationException("%s의 codeSnippet에 지나치게 긴 줄이 있습니다.".formatted(location));
        }
        return line;
    }
}
