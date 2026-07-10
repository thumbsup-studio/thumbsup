package studio.thumbsup.server.mascot;

import java.time.Clock;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.mascot.dto.MascotResponse;

/**
 * ⚠️ 클래스 레벨 {@code @Transactional(readOnly = true)}는 조회 전용 기본값이다.
 * 쓰기 메서드({@link #feed})는 별도로 {@code @Transactional}을 오버라이드한다.
 */
@Service
@Transactional(readOnly = true)
public class MascotService {

    private final MascotRepository mascotRepository;
    private final Clock clock;

    public MascotService(MascotRepository mascotRepository, Clock clock) {
        this.mascotRepository = mascotRepository;
        this.clock = clock;
    }

    /** 아직 한 번도 먹이를 준 적 없는 신규 유저는 행(row) 생성 없이 만실(100%) 기본값을 반환한다. */
    public MascotResponse getMascot(Long userId) {
        return mascotRepository
                .findByUserId(userId)
                .map(mascot -> MascotResponse.from(mascot.getCurrentFullness(clock.instant())))
                .orElseGet(() -> MascotResponse.from(Mascot.MAX_FULLNESS));
    }

    /**
     * 세션(퀴즈 5문제 세트) 완료 시 프론트가 호출 — 먹이를 준다.
     * 유저 최초 호출로 행이 없으면 새로 만든다 — quiz.QuizService#lockOrCreateProgress와 동일하게
     * 동시 생성 레이스는 유니크 제약 위반 후 재조회로 해소한다.
     */
    @Transactional
    public MascotResponse feed(Long userId) {
        Mascot mascot = lockOrCreateMascot(userId);
        mascot.feed(clock.instant());
        mascotRepository.save(mascot);
        return MascotResponse.from(mascot.getFullnessAtLastFeed());
    }

    private Mascot lockOrCreateMascot(Long userId) {
        return mascotRepository.findByUserIdForUpdate(userId).orElseGet(() -> createMascot(userId));
    }

    private Mascot createMascot(Long userId) {
        try {
            return mascotRepository.saveAndFlush(Mascot.create(userId, clock.instant()));
        } catch (DataIntegrityViolationException e) {
            return mascotRepository.findByUserIdForUpdate(userId).orElseThrow();
        }
    }
}
