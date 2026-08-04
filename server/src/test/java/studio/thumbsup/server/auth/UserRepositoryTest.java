package studio.thumbsup.server.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import studio.thumbsup.server.common.support.RepositoryTestSupport;

class UserRepositoryTest extends RepositoryTestSupport {

    private final UserRepository userRepository;

    UserRepositoryTest(@Autowired UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Test
    void 이메일로_유저를_조회한다() {
        userRepository.save(User.create("a@test.com", "hashed"));

        assertThat(userRepository.findByEmail("a@test.com")).isPresent();
        assertThat(userRepository.findByEmail("nobody@test.com")).isEmpty();
    }

    @Test
    void 이메일_존재_여부를_확인한다() {
        userRepository.save(User.create("dup@test.com", "hashed"));

        assertThat(userRepository.existsByEmail("dup@test.com")).isTrue();
        assertThat(userRepository.existsByEmail("nobody@test.com")).isFalse();
    }

    @Test
    void 이메일_중복_저장은_제약_위반으로_거부된다() {
        userRepository.saveAndFlush(User.create("dup@test.com", "hashed"));

        assertThrows(
                DataIntegrityViolationException.class,
                () -> userRepository.saveAndFlush(User.create("dup@test.com", "other-hash")));
    }
}
