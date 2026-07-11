package studio.thumbsup.server.quiz.generation;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** 코드처럼 보이는 한 줄 안의 따옴표, 인덱스, 호출 인자 구조를 보수적으로 검증한다. */
final class CodeSnippetLineGuard {

    private static final Pattern FUNCTION_CALL_CANDIDATE =
            Pattern.compile("(?<![A-Za-z0-9_$])(" + CodeSnippetValidator.ACCESS + ")\\s*\\(");
    private static final Pattern CALL_ARGUMENT_LIST = Pattern.compile("^\\s*(?:"
            + CodeSnippetValidator.CALL_ARGUMENT_OR_STAR
            + "(?:\\s*,\\s*"
            + CodeSnippetValidator.CALL_ARGUMENT_OR_STAR
            + ")*)?\\s*$");
    private static final Pattern CONTROL_CALL_NAME =
            Pattern.compile("^(?:if|for|while|switch|catch|with)$", Pattern.CASE_INSENSITIVE);
    private static final Pattern INDEX_EXPRESSION =
            Pattern.compile("^\\s*" + CodeSnippetValidator.INDEX_EXPRESSION + "\\s*$");

    private CodeSnippetLineGuard() {}

    static boolean isValid(String line) {
        if (!hasBalancedQuotes(line) || !hasOnlyStructuredIndexes(line)) {
            return false;
        }
        return CodeSnippetValidator.isFunctionDeclarationLine(line) || hasOnlyStructuredCallArguments(line);
    }

    static int findClosingParenthesis(String line, int openingParenthesis) {
        int depth = 1;
        for (int index = openingParenthesis + 1; index < line.length(); index++) {
            int closingQuote = closingQuoteAt(line, index);
            if (closingQuote < 0) {
                return -1;
            }
            if (closingQuote != index) {
                index = closingQuote;
                continue;
            }
            char current = line.charAt(index);
            if (current == '(') {
                depth++;
            } else if (current == ')' && --depth == 0) {
                return index;
            }
        }
        return -1;
    }

    private static boolean hasBalancedQuotes(String line) {
        for (int index = 0; index < line.length(); index++) {
            int closingQuote = closingQuoteAt(line, index);
            if (closingQuote < 0) {
                return false;
            }
            if (closingQuote != index) {
                index = closingQuote;
            }
        }
        return true;
    }

    private static boolean hasOnlyStructuredIndexes(String line) {
        String code = line.substring(0, findInlineCommentStart(line));
        int openingBracket = -1;
        for (int index = 0; index < code.length(); index++) {
            int closingQuote = closingQuoteAt(code, index);
            if (closingQuote < 0) {
                return false;
            }
            if (closingQuote != index) {
                index = closingQuote;
                continue;
            }
            char current = code.charAt(index);
            if (current == '[') {
                if (openingBracket >= 0) {
                    return false;
                }
                openingBracket = index;
                continue;
            }
            if (current != ']') {
                continue;
            }
            if (!isValidClosingBracket(code, openingBracket, index)) {
                return false;
            }
            openingBracket = -1;
        }
        return openingBracket < 0;
    }

    private static boolean isValidClosingBracket(String code, int openingBracket, int closingBracket) {
        if (openingBracket < 0) {
            return false;
        }
        String expression = code.substring(openingBracket + 1, closingBracket);
        return expression.isBlank() || INDEX_EXPRESSION.matcher(expression).matches();
    }

    private static boolean hasOnlyStructuredCallArguments(String line) {
        String code = line.substring(0, findInlineCommentStart(line));
        Matcher calls = FUNCTION_CALL_CANDIDATE.matcher(code);
        while (calls.find()) {
            if (isInsideQuotedSegment(code, calls.start())) {
                continue;
            }
            String callee = calls.group(1);
            if (isStructuredControlCall(code, calls.start(), callee)) {
                continue;
            }
            int openingParenthesis = calls.end() - 1;
            int closingParenthesis = findClosingParenthesis(code, openingParenthesis);
            if (!hasValidArguments(code, openingParenthesis, closingParenthesis)) {
                return false;
            }
            calls.region(closingParenthesis + 1, code.length());
        }
        return true;
    }

    private static boolean hasValidArguments(String code, int openingParenthesis, int closingParenthesis) {
        return closingParenthesis >= 0
                && CALL_ARGUMENT_LIST
                        .matcher(code.substring(openingParenthesis + 1, closingParenthesis))
                        .matches();
    }

    private static boolean isStructuredControlCall(String code, int callStart, String callee) {
        return CONTROL_CALL_NAME.matcher(callee).matches()
                && isControlStatementPosition(code, callStart)
                && CodeSnippetValidator.isStructuredControlLine(code.substring(callStart));
    }

    private static boolean isControlStatementPosition(String code, int callStart) {
        int index = callStart - 1;
        while (index >= 0 && Character.isWhitespace(code.charAt(index))) {
            index--;
        }
        return index < 0 || code.charAt(index) == '{' || code.charAt(index) == ';' || code.charAt(index) == '}';
    }

    private static int findInlineCommentStart(String line) {
        for (int index = 0; index < line.length() - 1; index++) {
            int closingQuote = closingQuoteAt(line, index);
            if (closingQuote < 0) {
                return line.length();
            }
            if (closingQuote != index) {
                index = closingQuote;
                continue;
            }
            if (line.charAt(index) == '/' && line.charAt(index + 1) == '/') {
                return index;
            }
        }
        return line.length();
    }

    private static boolean isInsideQuotedSegment(String line, int position) {
        for (int index = 0; index < position; index++) {
            int closingQuote = closingQuoteAt(line, index);
            if (closingQuote < 0 || closingQuote >= position) {
                return closingQuote != index;
            }
            if (closingQuote != index) {
                index = closingQuote;
            }
        }
        return false;
    }

    private static int closingQuoteAt(String line, int index) {
        char current = line.charAt(index);
        return current == '\'' || current == '"' ? skipQuotedSegment(line, index) : index;
    }

    private static int skipQuotedSegment(String line, int openingQuote) {
        char quote = line.charAt(openingQuote);
        for (int index = openingQuote + 1; index < line.length(); index++) {
            char current = line.charAt(index);
            if (current == '\\') {
                index++;
            } else if (current == quote) {
                return index;
            }
        }
        return -1;
    }
}
