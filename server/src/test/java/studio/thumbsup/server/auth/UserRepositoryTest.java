package studio.thumbsup.server.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.config.ClockConfig;
import studio.thumbsup.server.common.config.JpaAuditingConfig;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@Import({ClockConfig.class, JpaAuditingConfig.class})
@ActiveProfiles("test")
class UserRepositoryTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

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
