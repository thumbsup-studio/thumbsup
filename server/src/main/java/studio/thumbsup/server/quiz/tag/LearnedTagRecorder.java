package studio.thumbsup.server.quiz.tag;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import studio.thumbsup.server.common.event.QuizStepCompletedEvent;
import studio.thumbsup.server.quiz.QuizRepository;

/**
 * 지식 그래프(#233)의 유일한 데이터 소스 기록기 — 스텝을 처음 완료하는 시점에, 그 스텝 문제들에 걸린
 * 정규화된 태그({@code quiz_tag} 링크가 있는 것만)를 유저의 학습 기록({@code user_tag}/
 * {@code user_tag_step})으로 남긴다. 어떤 태그를 어떻게 기록할지는 전부 tag 서브도메인의
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
 * <p><b>동시성 안전 근거(#324로 갱신)</b> — 예전에는 "① 유저·코스 단위 비관적 락으로 같은 코스 내
 * 동시 완료는 직렬화됨, ② 하나의 태그는 하나의 코스에서만 출제된다는 시드 큐레이션 불변식" 두 가지를
 * 근거로 조회 후 삽입이 안전하다고 봤다. 태그가 여러 코스에서 재사용될 수 있게 되면서 ②가 깨져,
 * 서로 다른 코스를 동시에 완료하며 같은 태그를 처음 학습하는 경합이 가능해졌다. 이제는 조회 후 삽입
 * 대신 {@link UserTagRepository#upsert}(네이티브 {@code INSERT ... ON DUPLICATE KEY UPDATE})로 유저·
 * 태그당 최초 1행만 남도록 DB가 직접 멱등성을 보장한다 — JPA {@code save()}가 unique 제약 위반
 * 예외를 던지면 persistence context가 rollback-only로 마킹돼 같은 트랜잭션의 다른 작업(진행도 갱신 등)
 * 까지 커밋 실패할 수 있기 때문에 예외 catch 방식 대신 upsert를 쓴다. {@code UserTagStep}은 멱등
 * 보호가 필요 없는 별도 관심사라 upsert 성패와 무관하게 항상 독립적으로 insert한다 — 한 루프에서
 * 묶어 경합에서 "졌다"고 판단된 스레드가 스텝 기록까지 스킵하면, 그 스텝이 {@code relatedSteps}에서
 * 영구 누락되기 때문이다(insert-once라 복구 불가).
 *
 * <p>네이티브 insert는 JPA Auditing(created_at/updated_at 자동 채움)을 우회하므로, 주입받은
 * {@link Clock}으로 타임스탬프를 직접 계산해 넘긴다.
 */
@Component
public class LearnedTagRecorder {

    private final QuizRepository quizRepository;
    private final QuizTagRepository quizTagRepository;
    private final UserTagRepository userTagRepository;
    private final UserTagStepRepository userTagStepRepository;
    private final Clock clock;

    public LearnedTagRecorder(
            QuizRepository quizRepository,
            QuizTagRepository quizTagRepository,
            UserTagRepository userTagRepository,
            UserTagStepRepository userTagStepRepository,
            Clock clock) {
        this.quizRepository = quizRepository;
        this.quizTagRepository = quizTagRepository;
        this.userTagRepository = userTagRepository;
        this.userTagStepRepository = userTagStepRepository;
        this.clock = clock;
    }

    @EventListener
    public void onStepCompleted(QuizStepCompletedEvent event) {
        List<Long> stepQuizIds = quizRepository.findIdsByQuizStepId(event.quizStepId());
        record(event.userId(), event.quizStepId(), stepQuizIds);
    }

    public void record(Long userId, Long quizStepId, List<Long> stepQuizIds) {
        List<Long> tagIds = quizTagRepository.findDistinctTagIdsByQuizIdIn(stepQuizIds);
        if (tagIds.isEmpty()) {
            return;
        }

        Instant now = clock.instant();
        for (Long tagId : tagIds) {
            userTagRepository.upsert(userId, tagId, now);
            userTagStepRepository.save(UserTagStep.create(userId, tagId, quizStepId));
        }
    }
}
