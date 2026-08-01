package studio.thumbsup.server.quiz.authoring;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizDerivedConcept;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;

/**
 * 라이브 {@link Quiz}를 {@link GeneratedQuizSet.GeneratedQuiz}로 역매핑한다 — 개선(IMPROVE) draft를 만들 때
 * 원본 문제를 AI가 소비할 수 있는 스키마로 되돌리는 용도다(#174). 생성 파이프라인의 순방향 매핑
 * ({@code QuizPersister.populate})과 반대 방향.
 */
public final class QuizToGeneratedQuizMapper {

    private QuizToGeneratedQuizMapper() {}

    public static GeneratedQuizSet.GeneratedQuiz toGenerated(Quiz quiz) {
        List<GeneratedQuizSet.GeneratedChoice> choices = quiz.getChoices().stream()
                .map(c -> new GeneratedQuizSet.GeneratedChoice(c.getContent(), c.isCorrect()))
                .toList();

        // slotOrder별 그룹핑 (순서 보장 위해 TreeMap)
        Map<Integer, List<String>> grouped = new TreeMap<>();
        quiz.getAnswerKeywords().forEach(k -> grouped.computeIfAbsent(k.getSlotOrder(), x -> new ArrayList<>())
                .add(k.getKeyword()));
        List<List<String>> answerKeywords = new ArrayList<>(grouped.values());

        List<GeneratedQuizSet.GeneratedFollowUpQuestion> followUps = quiz.getFollowUpQuestions().stream()
                .map(f -> new GeneratedQuizSet.GeneratedFollowUpQuestion(
                        f.getContent(),
                        f.isPrimary(),
                        f.getDifficulty(),
                        f.getOneLineAnswer(),
                        f.getBlocks().stream()
                                .map(b -> new GeneratedQuizSet.GeneratedFollowUpBlock(b.getLabel(), b.getContent()))
                                .toList(),
                        f.getKeywords().stream()
                                .map(k -> new GeneratedQuizSet.GeneratedKeyword(k.getKeyword(), k.getDescription()))
                                .toList()))
                .toList();

        return new GeneratedQuizSet.GeneratedQuiz(
                quiz.getType(),
                quiz.getDifficulty(),
                quiz.getQuestionText(),
                quiz.getHint(),
                quiz.getCodeSnippet(),
                quiz.getExplanationSummary(),
                quiz.getExplanationExample(),
                quiz.getWrongAnswerExplanation(),
                quiz.getCorrectAnswer(),
                choices,
                answerKeywords,
                followUps,
                quiz.getDerivedConcepts().stream()
                        .map(QuizDerivedConcept::getName)
                        .toList(),
                quiz.getKeywords().stream()
                        .map(k -> new GeneratedQuizSet.GeneratedKeyword(k.getKeyword(), k.getDescription()))
                        .toList());
    }
}
