package studio.thumbsup.server.quiz.generation;

import java.text.Normalizer;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.regex.Pattern;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizType;

/** 생성·저작된 한 문장 힌트가 정답을 직접 노출하지 않는지 저장 전에 검증한다(#193). */
final class QuizHintValidator {

    private static final int MAX_HINT_LENGTH = 200;
    private static final Pattern SENTENCE_END =
            Pattern.compile("[!?。！？]|(?<![A-Za-z0-9_$])\\.|(?<![A-Za-z]\\.[A-Za-z])\\.(?![A-Za-z0-9_$])");
    private static final Pattern DIRECT_ANSWER = Pattern.compile("(?<![\\p{L}\\p{N}])(?:정답|답)\\s*(?:은|는|이|가|:)");
    private static final String BARE_OPTION_LABEL = "(?:\\((?:[1-9]|[A-Da-d]|[가나다라])\\)|[1-9]|[①-⑨]|[A-Da-d]|[가나다라])";
    private static final String PREFIXED_OPTION_LABEL = "(?:\\((?:[1-9]|[A-Da-d]|[가나다라])\\)|[1-9]|[①-⑨]|[A-Da-d])";
    private static final String OPTION_LABEL = "(?<![\\p{L}\\p{N}])" + BARE_OPTION_LABEL;
    private static final Pattern CHOICE_LABEL = Pattern.compile(OPTION_LABEL + "\\s*(?:번|번째|선택지|보기)"
            + "|(?:선택지|보기)\\s*(?:번호\\s*)?" + PREFIXED_OPTION_LABEL
            + "|(?:선택지|보기)\\s+[가나다라]"
            + "|(?:첫|두|세|네)\\s*번째\\s*(?:선택지|보기)"
            + "|" + OPTION_LABEL + "\\s*(?:을|를)?\\s*(?:선택|고르|확인)");
    private static final Pattern OX_LABEL =
            Pattern.compile("(?i)(?<![A-Z0-9/\\-])[OX]\\s*(?:/|또는|이나|나)\\s*[OX](?![A-Z0-9])"
                    + "|(?<![A-Z0-9/\\-])[OX]\\s*(?:를|을|로|라고|이|가)?\\s*"
                    + "(?:정답|선택|고르|표시|판단|입니다|이다)");
    private static final String LABEL_VERDICT_PREDICATE =
            "(?:맞아요|맞습니다|맞다|옳아요|옳습니다|옳다|" + "틀려요|틀립니다|틀리다|틀렸어요|틀렸습니다|틀렸다|정답이에요|정답입니다|정답이다)";
    private static final Pattern OX_LABEL_VERDICT = Pattern.compile("(?i)(?<![A-Z0-9/\\-])(?:\\([OX]\\)|[OX])"
            + "\\s*(?:가|는|이|은)?\\s*"
            + LABEL_VERDICT_PREDICATE
            + "(?![\\p{L}\\p{N}])");
    private static final Pattern CHOICE_LABEL_VERDICT = Pattern.compile("(?i)(?<![\\p{L}\\p{N}/\\-])"
            + BARE_OPTION_LABEL
            + "\\s*(?:가|는|이|은)?\\s*"
            + LABEL_VERDICT_PREDICATE
            + "(?![\\p{L}\\p{N}])");
    private static final String OX_VERDICT_PREDICATE = "(?:참입니다|참이다|참이에요|거짓입니다|거짓이다|거짓이에요|"
            + "사실입니다|사실이다|성립합니다|성립한다|올바릅니다|올바르다|"
            + "옳습니다|옳다|틀렸습니다|틀리다|맞습니다|맞다|아닙니다|아니다|아니에요|"
            + "사실이 아닙니다|성립하지 않습니다|성립하지 않는다|올바르지 않습니다|올바르지 않다)";
    private static final Pattern OX_VERDICT = Pattern.compile("(?:참|거짓)(?:을|를|으로|이라고)?\\s*(?:판단|선택|표시|고르)"
            + "|^\\s*" + OX_VERDICT_PREDICATE + "\\s*[.!?。！？]?\\s*$"
            + "|(?:(?:이\\s*)?(?:설명|문장|명제|내용|주장)(?:은|는|이|가)?|따라서|그러므로|결론적으로)\\s*"
            + OX_VERDICT_PREDICATE
            + "|(?:옳은|틀린|맞는|아닌)\\s*(?:설명|문장|명제)\\s*(?:입니다|이다)");
    private static final Pattern NON_ALPHANUMERIC = Pattern.compile("[^\\p{L}\\p{N}]");

    private QuizHintValidator() {}

    static void validate(String location, GeneratedQuizSet.GeneratedQuiz quiz) {
        List<String> correctChoices = quiz.choices() == null
                ? List.of()
                : quiz.choices().stream()
                        .filter(Objects::nonNull)
                        .filter(GeneratedQuizSet.GeneratedChoice::isCorrect)
                        .map(GeneratedQuizSet.GeneratedChoice::content)
                        .filter(Objects::nonNull)
                        .toList();
        List<String> answerKeywords = quiz.answerKeywords() == null
                ? List.of()
                : quiz.answerKeywords().stream()
                        .filter(group -> group != null)
                        .flatMap(List::stream)
                        .filter(Objects::nonNull)
                        .toList();
        validate(location, quiz.type(), quiz.hint(), correctChoices, answerKeywords);
    }

    /** Flyway로 백필된 라이브 엔티티도 생성물과 같은 누출 정책으로 검증한다. */
    static void validate(String location, Quiz quiz) {
        List<String> correctChoices = quiz.getChoices().stream()
                .filter(choice -> choice.isCorrect())
                .map(choice -> choice.getContent())
                .toList();
        List<String> answerKeywords = quiz.getAnswerKeywords().stream()
                .map(keyword -> keyword.getKeyword())
                .toList();
        validate(location, quiz.getType(), quiz.getHint(), correctChoices, answerKeywords);
    }

    private static void validate(
            String location, QuizType type, String hint, List<String> correctChoices, List<String> answerKeywords) {
        String trimmed = validateCommon(location, hint);
        validateTypeSpecific(location, type, trimmed, correctChoices, answerKeywords);
    }

    private static String validateCommon(String location, String hint) {
        if (hint == null || hint.isBlank()) {
            throw new QuizGenerationException("%s의 hint가 비어 있습니다.".formatted(location));
        }

        String trimmed = hint.trim();
        if (trimmed.length() > MAX_HINT_LENGTH) {
            throw new QuizGenerationException("%s의 hint가 %d자를 초과했습니다.".formatted(location, MAX_HINT_LENGTH));
        }
        if (hint.contains("\n") || hint.contains("\r")) {
            throw new QuizGenerationException("%s의 hint는 개행 없는 한 문장이어야 합니다.".formatted(location));
        }
        validateSingleSentence(location, trimmed);
        if (trimmed.contains("[[") || trimmed.contains("]]")) {
            throw new QuizGenerationException("%s의 hint에는 키워드 마커를 넣을 수 없습니다.".formatted(location));
        }
        if (DIRECT_ANSWER.matcher(trimmed).find()) {
            throw new QuizGenerationException("%s의 hint가 정답을 직접 지시합니다.".formatted(location));
        }
        return trimmed;
    }

    private static void validateSingleSentence(String location, String hint) {
        if (hint.contains("\n") || hint.contains("\r") || hasMoreThanOneSentence(hint)) {
            throw new QuizGenerationException("%s의 hint는 개행 없는 한 문장이어야 합니다.".formatted(location));
        }
    }

    private static void validateTypeSpecific(
            String location, QuizType type, String hint, List<String> correctChoices, List<String> answerKeywords) {
        switch (type) {
            case OX -> validateOx(location, hint);
            case MULTIPLE_CHOICE -> validateMultipleChoice(location, hint, correctChoices);
            case KEYWORD_BLANK -> validateKeywordBlank(location, hint, answerKeywords);
        }
    }

    private static boolean hasMoreThanOneSentence(String hint) {
        String withoutFinalPunctuation = hint.replaceFirst("[.!?。！？]$", "");
        return SENTENCE_END.matcher(withoutFinalPunctuation).find();
    }

    private static void validateOx(String location, String hint) {
        if (OX_LABEL.matcher(hint).find()
                || OX_LABEL_VERDICT.matcher(hint).find()
                || OX_VERDICT.matcher(hint).find()) {
            throw new QuizGenerationException("%s의 OX hint가 참·거짓 판단 결론을 직접 말합니다.".formatted(location));
        }
    }

    private static void validateMultipleChoice(String location, String hint, List<String> correctChoices) {
        if (CHOICE_LABEL.matcher(hint).find()
                || CHOICE_LABEL_VERDICT.matcher(hint).find()) {
            throw new QuizGenerationException("%s의 사지선다 hint가 선택지 라벨을 직접 말합니다.".formatted(location));
        }
        String normalizedHint = normalize(hint);
        boolean exposesCorrectChoice = correctChoices.stream()
                .filter(Objects::nonNull)
                .map(QuizHintValidator::normalize)
                .filter(content -> !content.isEmpty())
                .anyMatch(normalizedHint::contains);
        if (exposesCorrectChoice) {
            throw new QuizGenerationException("%s의 사지선다 hint가 정답 선택지 문구를 직접 말합니다.".formatted(location));
        }
    }

    private static void validateKeywordBlank(String location, String hint, List<String> answerKeywords) {
        String normalizedHint = normalize(hint);
        boolean exposesAnswer = answerKeywords.stream()
                .filter(Objects::nonNull)
                .map(QuizHintValidator::normalize)
                .filter(keyword -> !keyword.isEmpty())
                .anyMatch(normalizedHint::contains);
        if (exposesAnswer) {
            throw new QuizGenerationException("%s의 빈칸 hint가 정답 키워드 또는 동의어를 직접 말합니다.".formatted(location));
        }
    }

    private static String normalize(String value) {
        String normalized = Normalizer.normalize(value, Normalizer.Form.NFKC).toLowerCase(Locale.ROOT);
        return NON_ALPHANUMERIC.matcher(normalized).replaceAll("");
    }
}
