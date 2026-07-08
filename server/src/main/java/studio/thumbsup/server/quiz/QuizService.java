package studio.thumbsup.server.quiz;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.dto.QuizNextResponse;

/**
 * ⚠️ 클래스 레벨 {@code @Transactional(readOnly = true)}는 조회 전용 기본값이다.
 * 쓰기 메서드를 추가하면 반드시 그 메서드에 {@code @Transactional}로 오버라이드한다.
 */
@Service
@Transactional(readOnly = true)
public class QuizService {

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

    /** 유저의 현재 진행 스텝에서, 아직 풀지 않은 문제 중 출제 순서가 가장 빠른 것을 반환한다. */
    public QuizNextResponse getNextQuiz(Long userId) {
        int stepOrder = quizProgressRepository
                .findByUserId(userId)
                .map(QuizProgress::getCurrentStepOrder)
                .orElse(1);

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
}
