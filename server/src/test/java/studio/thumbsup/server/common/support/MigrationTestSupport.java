package studio.thumbsup.server.common.support;

import org.junit.jupiter.api.BeforeEach;
import org.testcontainers.containers.MySQLContainer;
import studio.thumbsup.server.common.config.TestcontainersConfiguration;

/**
 * Spring 컨텍스트 없이 Flyway/JDBC로 마이그레이션을 직접 재생하는 테스트 공통 베이스.
 * 매 테스트 전 스키마를 완전히 비워, 테스트가 원하는 버전까지 마이그레이션을 스스로 통제할 수 있게 한다.
 */
public abstract class MigrationTestSupport {

    protected static final MySQLContainer<?> MYSQL = TestcontainersConfiguration.MYSQL_CONTAINER;

    @BeforeEach
    void cleanSchema() {
        TestcontainersConfiguration.cleanSchema();
    }
}
