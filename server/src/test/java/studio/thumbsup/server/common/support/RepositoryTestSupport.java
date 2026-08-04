package studio.thumbsup.server.common.support;

import org.junit.jupiter.api.BeforeAll;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import studio.thumbsup.server.common.config.ClockConfig;
import studio.thumbsup.server.common.config.JpaAuditingConfig;
import studio.thumbsup.server.common.config.TestcontainersConfiguration;

/**
 * Repository 통합 테스트(@DataJpaTest) 공통 베이스 — {@link TestcontainersConfiguration}의 공유 MySQL
 * 컨테이너를 쓰되, 클래스마다 {@link TestcontainersConfiguration#resetSchema()}로 스키마를 통째로
 * 재구성해 "테스트 클래스마다 새 컨테이너"와 동일한 격리를 유지한다.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Import({TestcontainersConfiguration.class, ClockConfig.class, JpaAuditingConfig.class, DatabaseCleanUp.class})
@ActiveProfiles("test")
public abstract class RepositoryTestSupport {

    @BeforeAll
    static void resetSchema() {
        TestcontainersConfiguration.resetSchema();
    }
}
