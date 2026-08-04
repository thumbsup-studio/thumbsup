package studio.thumbsup.server.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import studio.thumbsup.server.common.support.RepositoryTestSupport;

class RefreshTokenRepositoryTest extends RepositoryTestSupport {

    private final RefreshTokenRepository refreshTokenRepository;
    private final UserRepository userRepository;

    RefreshTokenRepositoryTest(
            @Autowired RefreshTokenRepository refreshTokenRepository, @Autowired UserRepository userRepository) {
        this.refreshTokenRepository = refreshTokenRepository;
        this.userRepository = userRepository;
    }

    @Test
    void 토큰_해시로_조회한다() {
        User user1 = userRepository.save(User.create("user1@test.com", "password"));
        refreshTokenRepository.save(
                RefreshToken.create(user1.getId(), "hash-1", Instant.parse("2026-07-21T00:00:00Z")));

        assertThat(refreshTokenRepository.findByTokenHash("hash-1")).isPresent();
        assertThat(refreshTokenRepository.findByTokenHash("nope")).isEmpty();
    }

    @Test
    void 유저_id로_조회한다() {
        User user9 = userRepository.save(User.create("user9@test.com", "password"));
        refreshTokenRepository.save(
                RefreshToken.create(user9.getId(), "hash-9", Instant.parse("2026-07-21T00:00:00Z")));

        assertThat(refreshTokenRepository.findByUserId(user9.getId())).isPresent();
        assertThat(refreshTokenRepository.findByUserId(-1L)).isEmpty();
    }

    @Test
    void 유저_id로_삭제하면_조회되지_않는다() {
        User user7 = userRepository.save(User.create("user7@test.com", "password"));
        refreshTokenRepository.save(
                RefreshToken.create(user7.getId(), "hash-7", Instant.parse("2026-07-21T00:00:00Z")));

        refreshTokenRepository.deleteByUserId(user7.getId());

        assertThat(refreshTokenRepository.findByTokenHash("hash-7")).isEmpty();
    }
}
