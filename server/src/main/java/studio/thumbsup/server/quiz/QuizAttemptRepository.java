package studio.thumbsup.server.quiz;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface QuizAttemptRepository extends JpaRepository<QuizAttempt, Long> {

    /** 특정 스텝에서 이 유저가 이미 푼 시도 목록 — "다음 문제" 계산에 쓰인다. */
    List<QuizAttempt> findByUserIdAndQuiz_StepOrder(Long userId, int stepOrder);
}
