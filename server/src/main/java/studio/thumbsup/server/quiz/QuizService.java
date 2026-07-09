package studio.thumbsup.server.quiz;

import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.dto.AnswerSubmitRequest;
import studio.thumbsup.server.quiz.dto.AnswerSubmitResponse;
import studio.thumbsup.server.quiz.dto.QuizExplanationResponse;
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
     * 문제 하나의 해설을 조회한다 — 해설 화면(S4)이 그리는 콘텐츠 전부를 한 번에 내려준다.
     *
     * <p>해설은 quizId만으로 정해지는 정적 콘텐츠라 채점 결과에 의존하지 않는다. 그래서 정답 제출(#42)이
     * 쓴 풀이 이력을 읽지 않으며, 새로고침·딥링크·복습처럼 채점 없이 해설만 필요한 흐름에서도 그대로 쓰인다.
     */
    public QuizExplanationResponse getExplanation(Long quizId) {
        Quiz quiz =
                quizRepository.findById(quizId).orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
        return QuizExplanationResponse.from(quiz);
    }

    /**
     * 제출한 답을 채점하고 풀이 이력을 남긴다. 재시도를 허용하므로 이력은 매번 새로 쌓인다.
     * 이 시도로 현재 스텝의 모든 문제를 한 번씩 풀었다면(정답 여부 무관) 다음 스텝으로 진행 상태를 갱신한다.
     *
     * <p>격리 수준을 READ_COMMITTED로 낮춘 이유는 {@link #advanceProgressIfStepCompleted}에서 설명한다.
     */
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public AnswerSubmitResponse submitAnswer(Long userId, Long quizId, AnswerSubmitRequest request) {
        Quiz quiz =
                quizRepository.findById(quizId).orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
        validateAccessible(userId, quiz);

        boolean isCorrect = grade(quiz, request.answers());
        quizAttemptRepository.save(QuizAttempt.create(quiz, userId, isCorrect));
        advanceProgressIfStepCompleted(userId, quiz.getStepOrder());

        return new AnswerSubmitResponse(isCorrect);
    }

    /**
     * 유저의 현재 진행 스텝보다 미래인 스텝의 문제는 제출할 수 없다 — {@code /next}를 거치지 않고
     * quizId를 추측해 앞선 스텝을 건너뛰는 것을 막는다. 현재 스텝과 과거 스텝은 허용한다(복습 여지).
     */
    private void validateAccessible(Long userId, Quiz quiz) {
        int currentStepOrder = quizProgressRepository
                .findByUserId(userId)
                .map(QuizProgress::getCurrentStepOrder)
                .orElse(INITIAL_STEP_ORDER);
        if (quiz.getStepOrder() > currentStepOrder) {
            throw new BusinessException(QuizErrorType.QUIZ_NOT_ACCESSIBLE);
        }
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

    /**
     * 이 유저가 스텝의 모든 문제를 한 번씩 시도했는지 확인하고, 그렇다면 다음 스텝으로 진행시킨다.
     *
     * <p>같은 유저가 같은 스텝의 마지막 문제 두 개를 동시에 제출하면, 서로 상대방의 커밋을 못 본 채
     * 둘 다 "아직 미완료"로 판단해 진행이 영영 갱신되지 않는 레이스가 생길 수 있다. 이를 막기 위해
     * 진행 상태 행을 유저 단위로 비관적 락({@link QuizProgressRepository#findByUserIdForUpdate})으로
     * 잠가 이 구간을 직렬화한다 — 먼저 온 요청이 커밋할 때까지 나중 요청은 대기했다가, 커밋 후의
     * 최신 시도 이력을 다시 읽는다. 격리 수준을 READ_COMMITTED로 낮춘 이유도 이것과 짝을 이룬다 —
     * 기본 REPEATABLE READ에서는 트랜잭션 최초 조회 시점의 스냅샷이 고정되어, 락을 기다렸다 얻은
     * 뒤에도 그 사이 다른 트랜잭션이 커밋한 시도 이력을 못 볼 수 있다.
     */
    private void advanceProgressIfStepCompleted(Long userId, int stepOrder) {
        QuizProgress progress = lockOrCreateProgress(userId);

        List<Long> stepQuizIds = quizRepository.findIdsByStepOrder(stepOrder);
        Set<Long> attemptedQuizIds = quizAttemptRepository.findByUserIdAndQuiz_StepOrder(userId, stepOrder).stream()
                .map(attempt -> attempt.getQuiz().getId())
                .collect(Collectors.toSet());
        boolean stepCompleted = stepQuizIds.stream().allMatch(attemptedQuizIds::contains);
        if (!stepCompleted) {
            return;
        }

        if (progress.getCurrentStepOrder() == stepOrder) {
            progress.advanceToNextStep();
            quizProgressRepository.save(progress);
        }
    }

    /**
     * 진행 상태 행을 락을 건 채로 가져온다. 없으면 새로 만든다 — 유저가 처음으로 스텝을 완료하는
     * 순간 두 요청이 동시에 "행이 없다"를 보고 둘 다 생성을 시도할 수 있으므로, 유니크 제약 위반은
     * 상대가 먼저 만든 행을 락으로 다시 읽어 해소한다.
     */
    private QuizProgress lockOrCreateProgress(Long userId) {
        Optional<QuizProgress> existing = quizProgressRepository.findByUserIdForUpdate(userId);
        if (existing.isPresent()) {
            return existing.get();
        }
        try {
            return quizProgressRepository.saveAndFlush(QuizProgress.create(userId));
        } catch (DataIntegrityViolationException e) {
            return quizProgressRepository.findByUserIdForUpdate(userId).orElseThrow();
        }
    }
}
