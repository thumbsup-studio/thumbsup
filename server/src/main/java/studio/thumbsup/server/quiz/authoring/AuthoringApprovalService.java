package studio.thumbsup.server.quiz.authoring;

import java.time.Clock;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.QuizErrorType;
import studio.thumbsup.server.quiz.QuizRepository;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;
import studio.thumbsup.server.quiz.generation.GeneratedQuizValidator;
import studio.thumbsup.server.quiz.generation.QuizPersister;

/**
 * draft 승인 = materialize(#174). 승인 전까지 draft는 스테이징 영역일 뿐 라이브 데이터에 영향을 주지
 * 않는다 — NEW draft는 새 스텝으로 INSERT하고, IMPROVE draft는 원본 quiz의 id를 보존한 채 자식
 * 콘텐츠까지 in-place로 교체한다(orphanRemoval clear→재추가).
 */
@Service
public class AuthoringApprovalService {

    private final AuthoringDraftService draftService;
    private final AuthoringJobService jobService;
    private final GeneratedQuizValidator validator;
    private final QuizRepository quizRepository;
    private final QuizPersister quizPersister;
    private final Clock clock;

    public AuthoringApprovalService(
            AuthoringDraftService draftService,
            AuthoringJobService jobService,
            GeneratedQuizValidator validator,
            QuizRepository quizRepository,
            QuizPersister quizPersister,
            Clock clock) {
        this.draftService = draftService;
        this.jobService = jobService;
        this.validator = validator;
        this.quizRepository = quizRepository;
        this.quizPersister = quizPersister;
        this.clock = clock;
    }

    @Transactional
    public QuizDraft approve(Long userId, Long draftId) {
        QuizDraft draft = draftService.getOrThrow(draftId);
        if (draft.getStatus() == QuizDraftStatus.APPROVED) {
            throw new BusinessException(AuthoringErrorType.AUTHORING_DRAFT_ALREADY_APPROVED);
        }
        jobService.guardDraftHasNoActiveJob(draftId, clock.instant());

        GeneratedQuizSet set = validator.parse(draft.getCurrentPayload());
        if (draft.getOrigin() == QuizDraftOrigin.NEW) {
            quizPersister.persist(draft.getTopic(), set);
        } else {
            materializeImprove(draft, set);
        }

        draft.approve(userId, clock.instant());
        return draft;
    }

    private void materializeImprove(QuizDraft draft, GeneratedQuizSet set) {
        Quiz quiz = quizRepository
                .findById(draft.getSourceQuizId())
                .orElseThrow(() -> new BusinessException(QuizErrorType.QUIZ_NOT_FOUND));
        GeneratedQuizSet.GeneratedQuiz generated = set.quizzes().get(0);
        quiz.updateContent(
                generated.questionText(),
                generated.codeSnippet(),
                generated.explanationSummary(),
                generated.explanationExample(),
                generated.wrongAnswerExplanation());
        quiz.resetForRepopulation();
        quizPersister.populate(quiz, generated);
    }
}
