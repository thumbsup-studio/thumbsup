package studio.thumbsup.server.user;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import studio.thumbsup.server.common.event.QuizStepCompletedEvent;

/**
 * 퀴즈 풀이 트랜잭션이 커밋된 뒤(AFTER_COMMIT) 별도 트랜잭션으로 스트릭·포인트를 갱신한다.
 * 스트릭 갱신은 화면 표시용 부가 기능이라, 여기서 실패해도 이미 커밋된 퀴즈 풀이·진행 상태에는
 * 영향을 주지 않는다 — 실패 시 재시도 없이 로그만 남긴다(원인 대부분 일시적 DB 문제, 드문 케이스라
 * 재시도·아웃박스 같은 인프라는 과함).
 */
@Component
class UserProgressEventListener {

    private static final Logger log = LoggerFactory.getLogger(UserProgressEventListener.class);

    private final UserProgressService userProgressService;

    UserProgressEventListener(UserProgressService userProgressService) {
        this.userProgressService = userProgressService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onQuizStepCompleted(QuizStepCompletedEvent event) {
        try {
            userProgressService.recordStepCompletion(event.userId(), event.completedOn());
        } catch (RuntimeException e) {
            log.error("스트릭 갱신 실패 userId={}, completedOn={}", event.userId(), event.completedOn(), e);
        }
    }
}
