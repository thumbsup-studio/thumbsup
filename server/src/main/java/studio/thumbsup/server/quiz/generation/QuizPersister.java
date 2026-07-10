package studio.thumbsup.server.quiz.generation;

import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.quiz.FollowUpBlockType;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizFollowUpQuestion;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.QuizType;

/**
 * 검증을 마친 생성 결과를 DB에 저장한다(#26). {@link QuizGenerationService}에서 분리한 이유는
 * 트랜잭션 경계를 DB 저장에만 좁히기 위해서다 — 같은 클래스 안에서 {@code @Transactional} 메서드를
 * 자기 자신이 호출하면 Spring AOP 프록시를 거치지 않아(self-invocation) 트랜잭션이 적용되지 않는다.
 */
@Service
class QuizPersister {

    /** 생성 파이프라인은 소요 시간을 산출하지 않는다 — 콘텐츠 저작 시 수동 조정 예정인 MVP 기본값(#117). */
    private static final int DEFAULT_ESTIMATED_MINUTES = 3;

    private final QuizRepository quizRepository;
    private final QuizStepRepository quizStepRepository;

    QuizPersister(QuizRepository quizRepository, QuizStepRepository quizStepRepository) {
        this.quizRepository = quizRepository;
        this.quizStepRepository = quizStepRepository;
    }

    @Transactional
    int persist(String courseTopic, GeneratedQuizSet generated) {
        int stepOrder = quizRepository.findMaxStepOrder().map(max -> max + 1).orElse(1);

        // quiz.step_order가 FK로 quiz_step.step_order를 참조하므로 반드시 먼저 저장한다.
        quizStepRepository.save(QuizStep.create(stepOrder, courseTopic, DEFAULT_ESTIMATED_MINUTES));

        int slotOrder = 1;
        for (GeneratedQuizSet.GeneratedQuiz g : generated.quizzes()) {
            Quiz quiz = toEntity(g);
            quiz.assignPosition(stepOrder, slotOrder++);
            quizRepository.save(quiz);
        }
        return stepOrder;
    }

    private Quiz toEntity(GeneratedQuizSet.GeneratedQuiz g) {
        Quiz quiz = Quiz.create(
                g.type(),
                g.difficulty(),
                g.questionText(),
                g.codeSnippet(),
                g.explanationSummary(),
                g.explanationExample(),
                g.wrongAnswerExplanation());

        if (g.type() == QuizType.OX) {
            quiz.assignCorrectAnswer(g.correctAnswer());
        }
        if (g.type() == QuizType.MULTIPLE_CHOICE) {
            addChoices(quiz, g.choices());
        }
        if (g.type() == QuizType.KEYWORD_BLANK) {
            addAnswerKeywords(quiz, g.answerKeywords());
        }
        addFollowUpQuestions(quiz, g.followUpQuestions());
        addDerivedConcepts(quiz, g.derivedConcepts());
        g.keywords().forEach(keyword -> quiz.addKeyword(keyword.keyword(), keyword.description()));
        return quiz;
    }

    private void addChoices(Quiz quiz, List<GeneratedQuizSet.GeneratedChoice> choices) {
        int order = 1;
        for (GeneratedQuizSet.GeneratedChoice choice : choices) {
            quiz.addChoice(choice.content(), choice.isCorrect(), order++);
        }
    }

    private void addAnswerKeywords(Quiz quiz, List<List<String>> answerKeywords) {
        int slot = 1;
        for (List<String> synonyms : answerKeywords) {
            for (String keyword : synonyms) {
                quiz.addAnswerKeyword(slot, keyword);
            }
            slot++;
        }
    }

    /** 상세(난이도·한 줄 답)와 블록·키워드를 꼬리질문에 함께 붙인다 — 하나라도 빠지면 조회 API가 그 꼬리질문을 감춘다(#133). */
    private void addFollowUpQuestions(Quiz quiz, List<GeneratedQuizSet.GeneratedFollowUpQuestion> followUpQuestions) {
        int order = 1;
        for (GeneratedQuizSet.GeneratedFollowUpQuestion fq : followUpQuestions) {
            QuizFollowUpQuestion followUpQuestion = quiz.addFollowUpQuestion(fq.content(), fq.isPrimary(), order++);
            followUpQuestion.attachDetail(fq.difficulty(), fq.oneLineAnswer());
            addFollowUpBlocks(followUpQuestion, fq.blocks());
            fq.keywords().forEach(keyword -> followUpQuestion.addKeyword(keyword.keyword(), keyword.description()));
        }
    }

    private void addFollowUpBlocks(
            QuizFollowUpQuestion followUpQuestion, List<GeneratedQuizSet.GeneratedFollowUpBlock> blocks) {
        int order = 1;
        for (GeneratedQuizSet.GeneratedFollowUpBlock block : blocks) {
            followUpQuestion.addBlock(block.label(), FollowUpBlockType.TEXT, block.content(), order++);
        }
    }

    private void addDerivedConcepts(Quiz quiz, List<String> derivedConcepts) {
        int order = 1;
        for (String concept : derivedConcepts) {
            quiz.addDerivedConcept(concept, order++);
        }
    }
}
