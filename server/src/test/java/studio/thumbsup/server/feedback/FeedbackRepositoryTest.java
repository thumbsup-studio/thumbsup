package studio.thumbsup.server.feedback;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.config.ClockConfig;
import studio.thumbsup.server.common.config.JpaAuditingConfig;

/**
 * Repository 통합 테스트 — 실제 MySQL(Testcontainers)에 Flyway 마이그레이션을 적용해
 * 쿼리·스키마·감사 필드를 함께 검증한다 (피라미드 3층).
 * 슬라이스에는 @Configuration이 없으므로 Auditing/Clock을 @Import로 가져온다.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@Import({ClockConfig.class, JpaAuditingConfig.class})
@ActiveProfiles("test")
class FeedbackRepositoryTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final FeedbackRepository feedbackRepository;

    FeedbackRepositoryTest(@Autowired FeedbackRepository feedbackRepository) {
        this.feedbackRepository = feedbackRepository;
    }

    @Test
    void 저장하면_id가_채번된다() {
        Feedback saved = feedbackRepository.save(Feedback.create(7L, "좋아요"));

        assertThat(saved.getId()).isNotNull();
    }

    @Test
    void 감사_필드는_저장_시_자동으로_채워진다() {
        Feedback saved = feedbackRepository.save(Feedback.create(7L, "좋아요"));

        assertThat(saved.getCreatedAt()).isNotNull(); // Flyway NOT NULL 컬럼 + Auditing 동작 확인
        assertThat(saved.getUpdatedAt()).isNotNull();
    }
}
