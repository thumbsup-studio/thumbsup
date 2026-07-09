package studio.thumbsup.server.quiz;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.dto.AnswerSubmitRequest;
import studio.thumbsup.server.quiz.dto.AnswerSubmitResponse;
import studio.thumbsup.server.quiz.dto.QuizNextResponse;

/**
 * ⚠️ 클래스 레벨 {@code @Transactional(readOnly = true)}는 조회 전용 기본값이다.
 * 쓰기 메서드를 추가하면 반드시 그 메서드에 {@code @Transactional}로 오버라이드한다.
 */
@Service
@Transactional(readOnly = true)
public class QuizService {

    private static final int INITIAL_STEP_ORDER = 1;

    private final QuizRepository quizRepository;
    private final QuizAttemptRepository quizAttemptRepository;
    private final QuizProgressRepository quizProgressRepository;

    public QuizService(
            QuizRepository quizRepository,
            QuizAttemptRepository quizAttemptRepository,
            QuizProgressRepository quizProgressRepository) {
        this.quizRepository = quizRepository;
        this.quizAttemptRepository = quizAttemptRepository;
        this.quizProgressRepository = quizProgressRepository;
    }

    /**
     * 유저의 현재 진행 스텝에서, 아직 시도하지 않은 문제 중 출제 순서가 가장 빠른 것을 반환한다.
     * 오답이어도 같은 문제를 다시 내려주지 않고 다음 문제로 선형 진행한다(#58) — 즉시 재도전을 강제하지 않는다.
     * 틀린 문제의 복습은 이 흐름과 별개로, 저장된 풀이 이력(QuizAttempt)을 활용하는 향후 기능의 몫이다.
     */
    public QuizNextResponse getNextQuiz(Long userId) {
        int stepOrder = quizProgressRepository
                .findByUserId(userId)
                .map(QuizProgress::getCurrentStepOrder)
                .orElse(INITIAL_STEP_ORDER);

        List<Quiz> stepQuizzes = quizRepository.findByStepOrderOrderBySlotOrderAsc(stepOrder);
        if (stepQuizzes.isEmpty()) {
            throw new BusinessException(QuizErrorType.QUIZ_NOT_FOUND);
        }

        Set<Long> attemptedQuizIds = quizAttemptRepository.findByUserIdAndQuiz_StepOrder(userId, stepOrder).stream()
                .map(attempt -> attempt.getQuiz().getId())
                .collect(Collectors.toSet());

        Quiz next = stepQuizzes.stream()
                .filter(quiz -> !attemptedQuizIds.contains(quiz.getId()))
                .findFirst()
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_STEP_COMPLETED));

        return QuizNextResponse.from(next);
    }

    /**
     * 제출한 답을 채점하고 풀이 이력을 남긴다. 재시도를 허용하므로 이력은 매번 새로 쌓인다.
     * 이 시도로 현재 스텝의 모든 문제를 한 번씩 풀었다면(정답 여부 무관) 다음 스텝으로 진행 상태를 갱신한다.
     */
    @Transactional
    public AnswerSubmitResponse submitAnswer(Long userId, Long quizId, AnswerSubmitRequest request) {
        Quiz quiz =
                quizRepository.findById(quizId).orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));

        boolean isCorrect = grade(quiz, request.answers());
        quizAttemptRepository.save(QuizAttempt.create(quiz, userId, isCorrect));
        advanceProgressIfStepCompleted(userId, quiz.getStepOrder());

        return new AnswerSubmitResponse(isCorrect);
    }

    // if-else 사용 이유: enum switch 표현식은 컴파일러가 안전장치로 java.lang.MatchException 생성 코드를
    // 바이트코드에 삽입하는데, ArchUnit이 이를 "표준 예외 직접 생성"으로 오탐지한다(docs/error-implementation.md
    // 한계와 동일한 정적분석 한계).
    private boolean grade(Quiz quiz, List<String> answers) {
        if (quiz.getType() == QuizType.OX) {
            return gradeOx(quiz, answers);
        }
        if (quiz.getType() == QuizType.MULTIPLE_CHOICE) {
            return gradeMultipleChoice(quiz, answers);
        }
        return gradeKeywordBlank(quiz, answers);
    }

    private boolean gradeOx(Quiz quiz, List<String> answers) {
        return answers.get(0).equalsIgnoreCase(quiz.getCorrectAnswer());
    }

    private boolean gradeMultipleChoice(Quiz quiz, List<String> answers) {
        Long submittedChoiceId = parseChoiceId(answers.get(0));
        if (submittedChoiceId == null) {
            return false;
        }
        return quiz.getChoices().stream()
                .filter(choice -> choice.getId().equals(submittedChoiceId))
                .findFirst()
                .map(QuizChoice::isCorrect)
                .orElse(false);
    }

    private Long parseChoiceId(String rawChoiceId) {
        try {
            return Long.valueOf(rawChoiceId);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private boolean gradeKeywordBlank(Quiz quiz, List<String> answers) {
        List<QuizAnswerKeyword> correctKeywords = quiz.getAnswerKeywords(); // slotOrder 순 정렬 보장(@OrderBy)
        if (answers.size() != correctKeywords.size()) {
            return false;
        }
        for (int i = 0; i < answers.size(); i++) {
            if (!answers.get(i)
                    .trim()
                    .equalsIgnoreCase(correctKeywords.get(i).getKeyword().trim())) {
                return false;
            }
        }
        return true;
    }

    /** 이 유저가 스텝의 모든 문제를 한 번씩 시도했는지 확인하고, 그렇다면 다음 스텝으로 진행시킨다. */
    private void advanceProgressIfStepCompleted(Long userId, int stepOrder) {
        List<Quiz> stepQuizzes = quizRepository.findByStepOrderOrderBySlotOrderAsc(stepOrder);
        Set<Long> attemptedQuizIds = quizAttemptRepository.findByUserIdAndQuiz_StepOrder(userId, stepOrder).stream()
                .map(attempt -> attempt.getQuiz().getId())
                .collect(Collectors.toSet());
        boolean stepCompleted = stepQuizzes.stream().map(Quiz::getId).allMatch(attemptedQuizIds::contains);
        if (!stepCompleted) {
            return;
        }

        QuizProgress progress =
                quizProgressRepository.findByUserId(userId).orElseGet(() -> QuizProgress.create(userId));
        if (progress.getCurrentStepOrder() == stepOrder) {
            progress.advanceToNextStep();
        }
        quizProgressRepository.save(progress);
    }
}
