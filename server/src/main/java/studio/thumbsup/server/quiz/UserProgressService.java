package studio.thumbsup.server.quiz;

import java.time.LocalDate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * {@link UserProgress}(스트릭·포인트) 갱신만 담당한다. 유일한 쓰기 호출자는
 * {@link QuizService#advanceProgressIfStepCompleted}다 — 오늘의 학습(1스텝)을 처음 완료한
 * 시점에만 불린다.
 */
@Service
public class UserProgressService {

    private final UserProgressRepository userProgressRepository;

    public UserProgressService(UserProgressRepository userProgressRepository) {
        this.userProgressRepository = userProgressRepository;
    }

    @Transactional
    public void recordStepCompletion(Long userId, LocalDate today) {
        UserProgress progress =
                userProgressRepository.findByUserId(userId).orElseGet(() -> UserProgress.create(userId, 0, 0));
        progress.recordCompletion(today);
        userProgressRepository.save(progress);
    }
}
