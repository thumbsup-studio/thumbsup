package studio.thumbsup.server.quiz.generation;

import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.FollowUpBlockType;
import studio.thumbsup.server.quiz.LearningErrorType;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizFollowUpQuestion;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.QuizType;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;

/**
 * 검증을 마친 생성 결과를 DB에 저장한다(#26). 저작 파이프라인이 검증을 통과한 결과만 넘기며,
 * 트랜잭션 경계는 DB 저장에만 둔다.
 */
@Service
public class QuizPersister {

    /** 생성 파이프라인은 소요 시간을 산출하지 않는다 — 콘텐츠 저작 시 수동 조정 예정인 MVP 기본값(#117). */
    private static final int DEFAULT_ESTIMATED_MINUTES = 3;

    private final QuizRepository quizRepository;
    private final QuizStepRepository quizStepRepository;
    private final CourseRepository courseRepository;

    public QuizPersister(
            QuizRepository quizRepository, QuizStepRepository quizStepRepository, CourseRepository courseRepository) {
        this.quizRepository = quizRepository;
        this.quizStepRepository = quizStepRepository;
        this.courseRepository = courseRepository;
    }

    /**
     * 저작 파이프라인(#174)이 courseId 없이 호출하는 경로 — 코스 선택 UI가 아직 없어 기본 코스
     * (가장 먼저 생성된 코스)로 저장한다. CLI 생성 파이프라인처럼 코스를 명시해야 하면
     * {@link #persist(Long, String, GeneratedQuizSet)}를 쓴다.
     */
    @Transactional
    public int persist(String courseTopic, GeneratedQuizSet generated) {
        return persist(resolveDefaultCourseId(), courseTopic, generated);
    }

    @Transactional
    int persist(Long courseId, String courseTopic, GeneratedQuizSet generated) {
        validateHintsBeforePersisting(generated);
        return persistAtValidated(courseId, nextStepOrder(courseId), courseTopic, DEFAULT_ESTIMATED_MINUTES, generated);
    }

    /** 이미 정해진 스텝 순서에 생성 결과를 저장한다 — 목차 발행처럼 스테이징 순서를 보존해야 하는 경로가 쓴다. */
    @Transactional
    public int persistAt(
            Long courseId, int stepOrder, String courseTopic, int estimatedMinutes, GeneratedQuizSet generated) {
        validateHintsBeforePersisting(generated);
        return persistAtValidated(courseId, stepOrder, courseTopic, estimatedMinutes, generated);
    }

    private int persistAtValidated(
            Long courseId, int stepOrder, String courseTopic, int estimatedMinutes, GeneratedQuizSet generated) {
        // quiz.quiz_step_id가 FK로 quiz_step.id를 참조하므로(#292) 반드시 먼저 저장해 PK를 받아둔다.
        QuizStep step = quizStepRepository.save(QuizStep.create(stepOrder, courseId, courseTopic, estimatedMinutes));

        int slotOrder = 1;
        for (GeneratedQuizSet.GeneratedQuiz g : generated.quizzes()) {
            Quiz quiz = Quiz.create(
                    g.type(),
                    g.difficulty(),
                    g.questionText(),
                    g.codeSnippet(),
                    g.explanationSummary(),
                    g.explanationExample(),
                    g.wrongAnswerExplanation());
            quiz.assignHint(g.hint());
            populate(quiz, g);
            quiz.assignPosition(step.getId(), stepOrder, slotOrder++);
            quizRepository.save(quiz);
        }
        return stepOrder;
    }

    /** 그 코스의 라이브 스텝을 기준으로 다음 코스 내 상대 step_order를 계산한다(#292). */
    public int nextStepOrder(Long courseId) {
        return quizStepRepository.findMaxStepOrderByCourseId(courseId).orElse(0) + 1;
    }

    /** 뒤쪽 슬롯의 hint가 잘못돼도 스텝이나 앞쪽 문제를 먼저 쓰지 않도록 전체 세트를 저장 전에 검증한다. */
    private void validateHintsBeforePersisting(GeneratedQuizSet generated) {
        for (int index = 0; index < generated.quizzes().size(); index++) {
            QuizHintValidator.validate(
                    "슬롯 %d".formatted(index + 1), generated.quizzes().get(index));
        }
    }

    /** 생성 결과의 자식 콘텐츠(선택지·정답 키워드·꼬리질문·파생개념·키워드)를 이미 만들어진 quiz에 채운다. */
    public void populate(Quiz quiz, GeneratedQuizSet.GeneratedQuiz g) {
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

    private Long resolveDefaultCourseId() {
        return courseRepository
                .findFirstByOrderByIdAsc()
                .map(Course::getId)
                .orElseThrow(() -> new BusinessException(LearningErrorType.COURSE_NOT_FOUND));
    }
}
