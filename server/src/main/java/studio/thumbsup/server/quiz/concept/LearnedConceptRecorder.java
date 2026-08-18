package studio.thumbsup.server.quiz.concept;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import studio.thumbsup.server.common.event.QuizStepCompletedEvent;
import studio.thumbsup.server.quiz.QuizRepository;

/**
 * 지식 그래프(#233)의 유일한 데이터 소스 기록기 — 스텝을 처음 완료하는 시점에, 그 스텝 문제들에 걸린
 * 정규화된 개념({@code quiz_concept} 링크가 있는 것만)을 유저의 학습 기록({@code user_concept}/
 * {@code user_concept_step})으로 남긴다. 어떤 개념을 어떻게 기록할지는 전부 concept 서브도메인의
 * 지식이므로, {@code QuizService}는 "스텝을 처음 완료했다"는 사실({@link QuizStepCompletedEvent})만
 * 발행한다 — 직접 의존하면 체크스타일 생성자 파라미터 수 상한(7개)을 넘긴다.
 *
 * <p>이 컴포넌트를 이벤트 리스너와 별도 서비스 클래스로 더 쪼개지 않는다 — {@code user.UserProgressService}가
 * {@code UserProgressEventListener}와 분리된 이유는 {@code UserProgressPort}를 통해 다른 도메인에서도
 * 같이 쓰이는 다중 진입점 컴포넌트이기 때문이다. 이 클래스는 소비자가 이 이벤트 하나뿐이라 그 근거가
 * 적용되지 않는다(CLAUDE.md: "인터페이스는 구현이 2개 이상이거나 외부 경계일 때만").
 *
 * <p>이벤트는 스트릭 갱신(user 도메인)과도 공유되므로, 퀴즈 id 목록 같은 quiz 내부 구현 세부사항은
 * 싣지 않고 quizStepId만 받아 이 컴포넌트가 직접 {@link QuizRepository}로 조회한다.
 *
 * <p>{@link #onStepCompleted}는 평범한(= AFTER_COMMIT이 아닌) {@code @EventListener}라 발행 시점에
 * 동기적으로, 발행자와 같은 스레드·트랜잭션 안에서 실행된다 — 진행도 갱신과 학습 기록이 함께 커밋되거나
 * 함께 롤백되는 것은 이 메서드를 직접 호출하는 것과 동일하다. 완료 가드는 스텝당 한 번만 통과되므로
 * 이 기록이 유실되면 다시 쓸 기회가 없어, 별도 트랜잭션으로 미루는 AFTER_COMMIT 리스너는 쓰지 않는다.
 *
 * <p>같은 개념이 여러 스텝에 걸쳐 나올 수 있어({@link UserConcept}는 유저·개념당 최초 1행만) 이미
 * 학습한 개념인지 먼저 조회해 걸러낸다. 이 조회-후-삽입이 안전한 근거는 두 가지다: ① 호출자가
 * 유저·코스 단위 비관적 락 구간 안에서만 호출하므로 같은 코스의 동시 완료는 직렬화되고, ② 하나의
 * 개념은 하나의 코스에서만 출제된다는 시드 큐레이션 불변식(V20260801192745 참고) 덕에 서로 다른
 * 코스의 동시 완료가 같은 개념을 두고 경합하지 않는다. 개념이 코스를 넘나들게 되면 ②가 깨지므로
 * 그때는 중복 삽입을 멱등 처리(upsert)로 바꿔야 한다.
 */
@Component
public class LearnedConceptRecorder {

    private final QuizRepository quizRepository;
    private final QuizConceptRepository quizConceptRepository;
    private final UserConceptRepository userConceptRepository;
    private final UserConceptStepRepository userConceptStepRepository;

    public LearnedConceptRecorder(
            QuizRepository quizRepository,
            QuizConceptRepository quizConceptRepository,
            UserConceptRepository userConceptRepository,
            UserConceptStepRepository userConceptStepRepository) {
        this.quizRepository = quizRepository;
        this.quizConceptRepository = quizConceptRepository;
        this.userConceptRepository = userConceptRepository;
        this.userConceptStepRepository = userConceptStepRepository;
    }

    @EventListener
    public void onStepCompleted(QuizStepCompletedEvent event) {
        List<Long> stepQuizIds = quizRepository.findIdsByQuizStepId(event.quizStepId());
        record(event.userId(), event.quizStepId(), stepQuizIds);
    }

    public void record(Long userId, Long quizStepId, List<Long> stepQuizIds) {
        List<Long> conceptIds = quizConceptRepository.findDistinctConceptIdsByQuizIdIn(stepQuizIds);
        if (conceptIds.isEmpty()) {
            return;
        }

        Set<Long> alreadyLearnedConceptIds =
                userConceptRepository.findByUserIdAndConceptIdIn(userId, conceptIds).stream()
                        .map(UserConcept::getConceptId)
                        .collect(Collectors.toCollection(HashSet::new));

        for (Long conceptId : conceptIds) {
            if (!alreadyLearnedConceptIds.contains(conceptId)) {
                userConceptRepository.save(UserConcept.create(userId, conceptId));
            }
            userConceptStepRepository.save(UserConceptStep.create(userId, conceptId, quizStepId));
        }
    }
}
