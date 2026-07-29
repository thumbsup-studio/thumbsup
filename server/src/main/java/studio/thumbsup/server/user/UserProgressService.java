package studio.thumbsup.server.user;

import java.time.LocalDate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.common.user.UserProgressPort;
import studio.thumbsup.server.common.user.UserProgressSnapshot;

/**
 * {@link UserProgress}(스트릭·포인트) 조회·갱신을 담당한다. 다른 도메인은 {@link UserProgressPort}로만
 * 이 서비스를 소비한다 — 쓰기는 {@code common.event.QuizStepCompletedEvent}를 구독하는
 * {@link UserProgressEventListener}가, 읽기는 {@link #getSnapshot}이 담당한다.
 */
@Service
public class UserProgressService implements UserProgressPort {

    private final UserProgressRepository userProgressRepository;

    public UserProgressService(UserProgressRepository userProgressRepository) {
        this.userProgressRepository = userProgressRepository;
    }

    /**
     * {@code AFTER_COMMIT} 시점엔 원본 트랜잭션의 {@code EntityManagerHolder}가 아직 스레드에 바인딩된
     * 채라(Spring의 자원 unbind는 afterCommit 콜백 이후 실행됨) 기본 {@code REQUIRED}로는 그 트랜잭션에
     * 참여만 하고 새로 커밋되지 않는다 — {@code REQUIRES_NEW}로 별도 트랜잭션을 강제한다.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordStepCompletion(Long userId, LocalDate today) {
        UserProgress progress =
                userProgressRepository.findByUserId(userId).orElseGet(() -> UserProgress.create(userId, 0, 0));
        progress.recordCompletion(today);
        userProgressRepository.save(progress);
    }

    @Override
    @Transactional(readOnly = true)
    public UserProgressSnapshot getSnapshot(Long userId, LocalDate today) {
        return userProgressRepository
                .findByUserId(userId)
                .map(progress -> new UserProgressSnapshot(
                        progress.getEffectiveStreak(today),
                        progress.getPoints(),
                        today.equals(progress.getLastCompletedDate())))
                .orElseGet(UserProgressSnapshot::empty);
    }
}
