package studio.thumbsup.server.quiz.authoring;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.Quiz;
import studio.thumbsup.server.quiz.authoring.dto.DraftDetailResponse;
import studio.thumbsup.server.quiz.authoring.dto.DraftListResponse;
import studio.thumbsup.server.quiz.authoring.dto.DraftSummaryResponse;
import studio.thumbsup.server.quiz.generation.GeneratedQuizSet;
import studio.thumbsup.server.quiz.generation.QuizGenerationException;

/**
 * draft 스테이징 영역(#174)의 저장·조회를 담당한다. GENERATE/REVIEW 잡 결과를 draft·revision으로
 * 쌓는 것과, 라이브 문제를 개선 대상으로 복제하는 것이 이 서비스의 역할이다 — 승인(materialize)은
 * {@code AuthoringApprovalService}(T6)가 별도로 맡는다.
 */
@Service
public class AuthoringDraftService {

    private static final int FIRST_REVISION_NO = 1;

    private final QuizDraftRepository quizDraftRepository;
    private final QuizDraftRevisionRepository quizDraftRevisionRepository;
    private final AuthoringOutlineStepRepository outlineStepRepository;
    private final ObjectMapper objectMapper;

    public AuthoringDraftService(
            QuizDraftRepository quizDraftRepository,
            QuizDraftRevisionRepository quizDraftRevisionRepository,
            AuthoringOutlineStepRepository outlineStepRepository,
            ObjectMapper objectMapper) {
        this.quizDraftRepository = quizDraftRepository;
        this.quizDraftRevisionRepository = quizDraftRevisionRepository;
        this.outlineStepRepository = outlineStepRepository;
        this.objectMapper = objectMapper;
    }

    /** GENERATE 잡 결과로 새 draft를 만들고 rev1을 남긴다. */
    @Transactional
    public QuizDraft createFromGenerate(GenerationJob job, GeneratedQuizSet set) {
        String payloadJson = writeValueAsString(set);
        QuizDraft draft =
                quizDraftRepository.save(QuizDraft.createNew(job.getTopic(), payloadJson, job.getAssigneeUserId()));
        quizDraftRevisionRepository.save(
                QuizDraftRevision.create(draft.getId(), FIRST_REVISION_NO, payloadJson, null, null, job.getId()));
        job.attachDraft(draft.getId());
        return draft;
    }

    /** REVIEW 잡 결과로 currentPayload를 교체하고, 검수 요약을 담은 다음 revision을 남긴다. */
    @Transactional
    public QuizDraft applyReview(GenerationJob job, ReviewResult result) {
        QuizDraft draft = getOrThrow(job.getDraftId());
        String payloadJson = writeValueAsString(new GeneratedQuizSet(result.quizzes()));
        draft.applyRevision(payloadJson);

        int nextRevisionNo = quizDraftRevisionRepository
                .findTopByDraftIdOrderByRevisionNoDesc(draft.getId())
                .map(revision -> revision.getRevisionNo() + 1)
                .orElse(FIRST_REVISION_NO);
        quizDraftRevisionRepository.save(QuizDraftRevision.create(
                draft.getId(),
                nextRevisionNo,
                payloadJson,
                result.reviewSummary(),
                job.getAssigneeUserId(),
                job.getId()));
        return draft;
    }

    /** 라이브 문제를 개선 대상으로 복제한 draft를 만든다 — revision은 검수 잡 결과(applyReview)가 만드므로 여기선 쌓지 않는다. */
    @Transactional
    public QuizDraft createImproveDraft(Long userId, Quiz sourceQuiz, String stepTopic) {
        GeneratedQuizSet set = new GeneratedQuizSet(List.of(QuizToGeneratedQuizMapper.toGenerated(sourceQuiz)));
        String payloadJson = writeValueAsString(set);
        return quizDraftRepository.save(QuizDraft.createImprove(stepTopic, sourceQuiz.getId(), payloadJson, userId));
    }

    @Transactional(readOnly = true)
    public List<QuizDraft> list(QuizDraftStatus status) {
        return quizDraftRepository.findByStatusOrderByUpdatedAtDesc(status);
    }

    @Transactional(readOnly = true)
    public QuizDraft getOrThrow(Long draftId) {
        return quizDraftRepository
                .findById(draftId)
                .orElseThrow(() -> new BusinessException(AuthoringErrorType.AUTHORING_DRAFT_NOT_FOUND));
    }

    /** 뼈대 스텝 draft의 검수 프롬프트에 넣을 형제 스텝 주제를 일괄 조회한다. */
    @Transactional(readOnly = true)
    public List<String> outlineSiblingTopics(Long draftId) {
        return outlineStepRepository
                .findByDraftId(draftId)
                .map(currentStep ->
                        outlineStepRepository.findByOutlineIdOrderByOrderNoAsc(currentStep.getOutlineId()).stream()
                                .filter(step -> !step.getId().equals(currentStep.getId()))
                                .map(AuthoringOutlineStep::getTopic)
                                .toList())
                .orElse(List.of());
    }

    /**
     * 승인·검수 재요청 진입점 전용(#174 I2) — PESSIMISTIC_WRITE로 같은 draft에 대한 동시 write를
     * 직렬화한다. readOnly가 아니어야 한다(MySQL이 읽기전용 트랜잭션의 FOR UPDATE를 거부한다).
     */
    @Transactional
    public QuizDraft getForUpdate(Long draftId) {
        return quizDraftRepository
                .findByIdForUpdate(draftId)
                .orElseThrow(() -> new BusinessException(AuthoringErrorType.AUTHORING_DRAFT_NOT_FOUND));
    }

    @Transactional(readOnly = true)
    public List<QuizDraftRevision> revisions(Long draftId) {
        return quizDraftRevisionRepository.findByDraftIdOrderByRevisionNoDesc(draftId);
    }

    /** 소스 퀴즈에 이미 열린(검수 대기 중인) 개선 draft가 있는지 — 중복 개선 요청 방지 가드에 쓰인다(#174). */
    @Transactional(readOnly = true)
    public boolean hasOpenImproveDraft(Long sourceQuizId) {
        return quizDraftRepository.existsBySourceQuizIdAndStatus(sourceQuizId, QuizDraftStatus.DRAFT);
    }

    /** 컨트롤러(#174 T7)가 엔티티를 직접 만지지 않도록 목록 DTO 변환까지 여기서 끝낸다. */
    @Transactional(readOnly = true)
    public DraftListResponse listSummaries(QuizDraftStatus status) {
        List<DraftSummaryResponse> summaries = list(status).stream()
                .map(draft -> DraftSummaryResponse.from(
                        draft, (int) quizDraftRevisionRepository.countByDraftId(draft.getId())))
                .toList();
        return new DraftListResponse(summaries);
    }

    /** 컨트롤러(#174 T7)가 엔티티를 직접 만지지 않도록 상세 DTO 변환까지 여기서 끝낸다. */
    @Transactional(readOnly = true)
    public DraftDetailResponse getDetail(Long draftId) {
        QuizDraft draft = getOrThrow(draftId);
        List<QuizDraftRevision> revisionList = revisions(draftId);
        return DraftDetailResponse.from(draft, readTree(draft.getCurrentPayload()), revisionList);
    }

    private String writeValueAsString(GeneratedQuizSet set) {
        try {
            return objectMapper.writeValueAsString(set);
        } catch (JsonProcessingException e) {
            throw new QuizGenerationException("draft payload를 JSON으로 직렬화하지 못했습니다.", e);
        }
    }

    private JsonNode readTree(String json) {
        try {
            return objectMapper.readTree(json);
        } catch (JsonProcessingException e) {
            throw new QuizGenerationException("draft payload를 JSON으로 파싱하지 못했습니다.", e);
        }
    }
}
