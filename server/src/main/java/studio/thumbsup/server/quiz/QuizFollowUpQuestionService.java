package studio.thumbsup.server.quiz;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.quiz.dto.FollowUpQuestionDetailResponse;

@Service
@Transactional(readOnly = true)
public class QuizFollowUpQuestionService {

    private final QuizFollowUpQuestionRepository quizFollowUpQuestionRepository;

    public QuizFollowUpQuestionService(QuizFollowUpQuestionRepository quizFollowUpQuestionRepository) {
        this.quizFollowUpQuestionRepository = quizFollowUpQuestionRepository;
    }

    /**
     * 꼬리질문 하나의 상세를 조회한다 — 꼬리질문 화면이 그리는 콘텐츠 전부를 한 번에 내려준다.
     *
     * <p>해설(#43)과 마찬가지로 채점 결과에 의존하지 않는 정적 콘텐츠라 userId를 받지 않는다.
     * 접근 가드(#42의 {@code validateAccessible})도 두지 않는다 — 꼬리질문은 커리큘럼 진행 밖의
     * 곁가지이고, 이미 그 문제의 해설을 본 유저에게만 id가 노출되기 때문이다.
     *
     * <p>상세가 아직 저작되지 않은 꼬리질문은 해설 응답에서 걸러지므로 정상 흐름에서는 여기에 닿지 않는다.
     * id를 직접 찍어 부르는 경우를 위해 별도 에러로 구분한다.
     */
    public FollowUpQuestionDetailResponse getDetail(Long followUpQuestionId) {
        QuizFollowUpQuestion followUpQuestion = quizFollowUpQuestionRepository
                .findWithQuizById(followUpQuestionId)
                .orElseThrow(() -> new BusinessException(QuizErrorType.FOLLOW_UP_QUESTION_NOT_FOUND));

        if (!followUpQuestion.hasDetail()) {
            throw new BusinessException(QuizErrorType.FOLLOW_UP_DETAIL_NOT_FOUND);
        }
        return FollowUpQuestionDetailResponse.from(followUpQuestion);
    }
}
