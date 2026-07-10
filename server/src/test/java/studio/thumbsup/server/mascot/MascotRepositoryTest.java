package studio.thumbsup.server.mascot;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
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
import studio.thumbsup.server.common.DatabaseCleanUp;
import studio.thumbsup.server.common.config.ClockConfig;
import studio.thumbsup.server.common.config.JpaAuditingConfig;

/**
 * Repository 통합 테스트 — 실제 MySQL(Testcontainers)에 Flyway 마이그레이션을 적용해
 * 쿼리·유니크 제약·감사 필드를 함께 검증한다 (피라미드 3층).
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@Import({ClockConfig.class, JpaAuditingConfig.class, DatabaseCleanUp.class})
@ActiveProfiles("test")
class MascotRepositoryTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final MascotRepository mascotRepository;
    private final DatabaseCleanUp databaseCleanUp;

    MascotRepositoryTest(@Autowired MascotRepository mascotRepository, @Autowired DatabaseCleanUp databaseCleanUp) {
        this.mascotRepository = mascotRepository;
        this.databaseCleanUp = databaseCleanUp;
    }

    @BeforeEach
    void cleanSeedData() {
        databaseCleanUp.execute();
    }

    @Test
    void 유저_id로_조회한다() {
        Mascot saved = mascotRepository.save(Mascot.create(1L, Instant.parse("2026-07-01T00:00:00Z")));

        Optional<Mascot> found = mascotRepository.findByUserId(1L);

        assertThat(found).isPresent();
        assertThat(found.get().getId()).isEqualTo(saved.getId());
    }

    @Test
    void 유저당_한_행만_허용한다() {
        mascotRepository.saveAndFlush(Mascot.create(1L, Instant.parse("2026-07-01T00:00:00Z")));

        assertThatThrownBy(
                        () -> mascotRepository.saveAndFlush(Mascot.create(1L, Instant.parse("2026-07-02T00:00:00Z"))))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void 감사_필드는_저장_시_자동으로_채워진다() {
        Mascot saved = mascotRepository.save(Mascot.create(1L, Instant.parse("2026-07-01T00:00:00Z")));

        assertThat(saved.getCreatedAt()).isNotNull();
        assertThat(saved.getUpdatedAt()).isNotNull();
    }
}
