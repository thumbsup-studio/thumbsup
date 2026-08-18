package studio.thumbsup.server.quiz.authoring;

import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.authoring.dto.PublishResponse;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;
import studio.thumbsup.server.quiz.generation.GeneratedQuizValidator;
import studio.thumbsup.server.quiz.generation.QuizGenerationException;
import studio.thumbsup.server.quiz.generation.QuizPersister;

/** 승인된 뼈대를 한 트랜잭션에서 학습자용 코스로 승격한다. */
@Service
public class AuthoringPublishService {

    private final AuthoringOutlineRepository outlineRepository;
    private final AuthoringOutlineStepRepository stepRepository;
    private final QuizDraftRepository draftRepository;
    private final CourseRepository courseRepository;
    private final GeneratedQuizValidator validator;
    private final QuizPersister quizPersister;

    public AuthoringPublishService(
            AuthoringOutlineRepository outlineRepository,
            AuthoringOutlineStepRepository stepRepository,
            QuizDraftRepository draftRepository,
            CourseRepository courseRepository,
            GeneratedQuizValidator validator,
            QuizPersister quizPersister) {
        this.outlineRepository = outlineRepository;
        this.stepRepository = stepRepository;
        this.draftRepository = draftRepository;
        this.courseRepository = courseRepository;
        this.validator = validator;
        this.quizPersister = quizPersister;
    }

    @Transactional
    public PublishResponse publish(Long userId, Long outlineId) {
        AuthoringOutline outline = outlineRepository
                .findByIdForUpdate(outlineId)
                .orElseThrow(() -> new BusinessException(AuthoringErrorType.AUTHORING_OUTLINE_NOT_FOUND));
        if (outline.isPublished()) {
            throw new BusinessException(AuthoringErrorType.AUTHORING_OUTLINE_PUBLISHED);
        }

        List<AuthoringOutlineStep> steps = stepRepository.findByOutlineIdOrderByOrderNoAsc(outlineId);
        Map<Long, QuizDraft> drafts = requireApprovedDrafts(steps);
        Course course = courseRepository.save(Course.create(outline.getTitle(), outline.getCategory()));
        int stepOrderBase = quizPersister.nextStepOrder(course.getId());

        for (int index = 0; index < steps.size(); index++) {
            publishStep(course, steps.get(index), drafts, stepOrderBase + index);
        }
        outline.markPublished(course.getId());
        return new PublishResponse(course.getId(), steps.size());
    }

    private Map<Long, QuizDraft> requireApprovedDrafts(List<AuthoringOutlineStep> steps) {
        if (steps.isEmpty()) {
            throw new BusinessException(AuthoringErrorType.AUTHORING_OUTLINE_NOT_READY);
        }
        Set<Long> draftIds = new HashSet<>();
        for (AuthoringOutlineStep step : steps) {
            if (step.getDraftId() == null) {
                throw new BusinessException(AuthoringErrorType.AUTHORING_OUTLINE_NOT_READY);
            }
            draftIds.add(step.getDraftId());
        }
        Map<Long, QuizDraft> drafts = new HashMap<>();
        draftRepository.findByIdIn(draftIds).forEach(draft -> drafts.put(draft.getId(), draft));
        for (AuthoringOutlineStep step : steps) {
            QuizDraft draft = drafts.get(step.getDraftId());
            if (draft == null || draft.getStatus() != QuizDraftStatus.APPROVED) {
                throw new BusinessException(AuthoringErrorType.AUTHORING_OUTLINE_NOT_READY);
            }
        }
        return drafts;
    }

    private void publishStep(Course course, AuthoringOutlineStep step, Map<Long, QuizDraft> drafts, int stepOrder) {
        QuizDraft draft = drafts.get(step.getDraftId());
        try {
            GeneratedQuizSet set = validator.parse(draft.getCurrentPayload());
            validator.validateHintSet(set, draft.getPreset());
            quizPersister.persistAt(
                    course.getId(),
                    stepOrder,
                    step.getTopic(),
                    draft.getPreset().estimatedMinutes(),
                    set);
        } catch (QuizGenerationException exception) {
            throw new BusinessException(AuthoringErrorType.AUTHORING_OUTLINE_NOT_READY, exception);
        }
    }
}
