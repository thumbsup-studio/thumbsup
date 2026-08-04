package studio.thumbsup.server.common.config;

import jakarta.annotation.PreDestroy;
import org.flywaydb.core.Flyway;
import org.springframework.context.annotation.Configuration;
import org.testcontainers.containers.MySQLContainer;

/**
 * 모든 Repository/인수 테스트가 공유하는 MySQL Testcontainer.
 * 클래스 로딩 시 static 블록에서 1회만 기동해, 테스트 클래스마다 컨테이너를 새로 띄우는 비용을 없앤다.
 *
 * <p>클래스 단위 격리는 컨테이너 대신 {@link #resetSchema()}(clean+migrate)가 보장한다 — 컨테이너를
 * 공유하면 한 클래스가 {@code DatabaseCleanUp}으로 Flyway 시드를 지웠을 때 Flyway는 이미 적용된 버전으로
 * 기록돼 있어 다시 채워주지 않으므로, 매 테스트 클래스 시작 전 스키마를 통째로 재구성해야 한다.
 */
@Configuration
public class TestcontainersConfiguration {

    private static final String MIGRATION_LOCATION = "classpath:db/migration";

    public static final MySQLContainer<?> MYSQL_CONTAINER;

    static {
        MYSQL_CONTAINER = new MySQLContainer<>("mysql:8.4");
        MYSQL_CONTAINER.start();

        System.setProperty("spring.datasource.url", MYSQL_CONTAINER.getJdbcUrl());
        System.setProperty("spring.datasource.username", MYSQL_CONTAINER.getUsername());
        System.setProperty("spring.datasource.password", MYSQL_CONTAINER.getPassword());
    }

    /** Spring 컨텍스트를 쓰는 테스트용 — 스키마를 비우고 최신까지 재마이그레이션해 시드 데이터를 복원한다. */
    public static void resetSchema() {
        Flyway flyway = flyway();
        flyway.clean();
        flyway.migrate();
    }

    /** Flyway 버전을 직접 제어하는 raw 테스트용 — 스키마만 비우고, 마이그레이션 실행은 테스트가 스스로 한다. */
    public static void cleanSchema() {
        flyway().clean();
    }

    private static Flyway flyway() {
        return Flyway.configure()
                .dataSource(MYSQL_CONTAINER.getJdbcUrl(), MYSQL_CONTAINER.getUsername(), MYSQL_CONTAINER.getPassword())
                .cleanDisabled(false)
                .locations(MIGRATION_LOCATION)
                .load();
    }

    @PreDestroy
    public void preDestroy() {
        if (MYSQL_CONTAINER.isRunning()) {
            MYSQL_CONTAINER.stop();
        }
    }
}
