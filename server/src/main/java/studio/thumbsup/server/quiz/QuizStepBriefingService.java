package studio.thumbsup.server.quiz;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.dto.QuizNextResponse;
import studio.thumbsup.server.quiz.dto.QuizStepBriefingResponse;

/** 문제 풀이 전 브리핑 조회와, 브리핑에서 확정한 스텝의 일반 학습 시작을 담당한다. */
@Service
@Transactional(readOnly = true)
public class QuizStepBriefingService {

    private final CourseRepository courseRepository;
    private final QuizStepRepository quizStepRepository;
    private final QuizProgressRepository quizProgressRepository;
    private final QuizStepBriefingRepository quizStepBriefingRepository;
    private final QuizRepository quizRepository;
    private final QuizAttemptRepository quizAttemptRepository;

    public QuizStepBriefingService(
            CourseRepository courseRepository,
            QuizStepRepository quizStepRepository,
            QuizProgressRepository quizProgressRepository,
            QuizStepBriefingRepository quizStepBriefingRepository,
            QuizRepository quizRepository,
            QuizAttemptRepository quizAttemptRepository) {
        this.courseRepository = courseRepository;
        this.quizStepRepository = quizStepRepository;
        this.quizProgressRepository = quizProgressRepository;
        this.quizStepBriefingRepository = quizStepBriefingRepository;
        this.quizRepository = quizRepository;
        this.quizAttemptRepository = quizAttemptRepository;
    }

    public QuizStepBriefingResponse getNextBriefing(Long userId, Long courseId) {
        CurrentQuizStepResolver.CurrentQuizStep currentStep = resolveCurrentStep(userId, courseId);
        QuizStep step = findCurrentStep(currentStep);
        QuizStepBriefing briefing = quizStepBriefingRepository
                .findWithBlocksByQuizStepId(step.getId())
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_STEP_BRIEFING_NOT_AVAILABLE));
        return QuizStepBriefingResponse.from(step, briefing);
    }

    /** 브리핑 화면이 받은 quizStepId로 현재 스텝의 미시도 문제를 가져온다. */
    public QuizNextResponse getNextQuizForStep(Long userId, Long quizStepId) {
        QuizStep requestedStep = quizStepRepository
                .findById(quizStepId)
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
        CurrentQuizStepResolver.CurrentQuizStep currentStep = resolveCurrentStep(userId, requestedStep.getCourseId());
        validateCurrentStep(requestedStep, currentStep);

        List<Quiz> quizzes = quizRepository.findByQuizStepIdOrderBySlotOrderAsc(quizStepId);
        if (quizzes.isEmpty()) {
            throw new BusinessException(QuizErrorType.QUIZ_NOT_FOUND);
        }
        Set<Long> attemptedQuizIds = quizAttemptRepository.findByUserIdAndQuiz_QuizStepId(userId, quizStepId).stream()
                .map(attempt -> attempt.getQuiz().getId())
                .collect(Collectors.toSet());
        Quiz nextQuiz = quizzes.stream()
                .filter(quiz -> !attemptedQuizIds.contains(quiz.getId()))
                .findFirst()
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_STEP_COMPLETED));
        return QuizNextResponse.from(nextQuiz, requestedStep.getCourseId(), quizzes.size());
    }

    private CurrentQuizStepResolver.CurrentQuizStep resolveCurrentStep(Long userId, Long courseId) {
        return CurrentQuizStepResolver.resolve(
                userId, courseId, courseRepository, quizProgressRepository, quizStepRepository);
    }

    private QuizStep findCurrentStep(CurrentQuizStepResolver.CurrentQuizStep currentStep) {
        return quizStepRepository
                .findByCourseIdAndStepOrder(currentStep.courseId(), currentStep.stepOrder())
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
    }

    private void validateCurrentStep(QuizStep requestedStep, CurrentQuizStepResolver.CurrentQuizStep currentStep) {
        if (requestedStep.getStepOrder() > currentStep.stepOrder()) {
            throw new BusinessException(QuizErrorType.QUIZ_NOT_ACCESSIBLE);
        }
        if (requestedStep.getStepOrder() < currentStep.stepOrder()) {
            throw new BusinessException(QuizErrorType.QUIZ_STEP_NOT_CURRENT);
        }
    }
}
