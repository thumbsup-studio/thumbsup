package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationVersion;
import org.flywaydb.core.api.configuration.FluentConfiguration;
import org.flywaydb.core.api.output.MigrateResult;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/** MySQL 비트랜잭션 DDL 뒤에 프로세스가 끊겨도 다음 기동에서 백필을 안전하게 이어가는지 검증한다. */
@Testcontainers
class QuizHintMigrationRecoveryTest {

    private static final String BASE_VERSION = "20260728170200";
    private static final String SCHEMA_VERSION = "20260731194402";
    private static final String BACKFILL_VERSION = "20260731194403";

    @Container
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    @Test
    @DisplayName("컬럼 DDL 뒤 배포가 끊겨도 다음 기동이 백필만 적용하고 재기동은 무변경이다")
    void resumes_backfill_after_schema_only_deployment() throws SQLException {
        flywayAt(BASE_VERSION).migrate();

        MigrateResult schemaResult = flywayAt(SCHEMA_VERSION).migrate();

        assertThat(schemaResult.migrationsExecuted).isOne();
        assertThat(queryInt("""
                SELECT COUNT(*)
                FROM information_schema.columns
                WHERE table_schema = DATABASE()
                  AND table_name = 'quiz'
                  AND column_name = 'hint'
                """)).isOne();
        assertThat(queryInt("SELECT COUNT(*) FROM quiz WHERE hint IS NOT NULL")).isZero();
        assertThat(queryString("SELECT MAX(version) FROM flyway_schema_history WHERE success = 1"))
                .isEqualTo(SCHEMA_VERSION);

        MigrateResult backfillResult = flywayAt(BACKFILL_VERSION).migrate();

        assertThat(backfillResult.migrationsExecuted).isOne();
        assertThat(queryInt("SELECT COUNT(*) FROM quiz WHERE hint IS NOT NULL")).isEqualTo(73);
        assertThat(queryInt("SELECT COUNT(*) FROM flyway_schema_history WHERE success = 0"))
                .isZero();
        assertThat(queryString("SELECT MAX(version) FROM flyway_schema_history WHERE success = 1"))
                .isEqualTo(BACKFILL_VERSION);

        assertThat(flywayAt(BACKFILL_VERSION).migrate().migrationsExecuted).isZero();
    }

    private Flyway flywayAt(String version) {
        return configuration().target(MigrationVersion.fromVersion(version)).load();
    }

    // 타겟 버전 없이 레포 전체 최신까지 실행 — 이후 마이그레이션이 추가될 때마다 이 테스트가 깨지는 원인이라
    // flywayAt(BACKFILL_VERSION)으로 대체함 (#255). 사용처 없음.
    // private Flyway flyway() {
    //     return configuration().load();
    // }

    private FluentConfiguration configuration() {
        return Flyway.configure()
                .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
                .locations("classpath:db/migration");
    }

    private int queryInt(String sql) throws SQLException {
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(sql);
                ResultSet resultSet = statement.executeQuery()) {
            assertThat(resultSet.next()).isTrue();
            return resultSet.getInt(1);
        }
    }

    private String queryString(String sql) throws SQLException {
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(sql);
                ResultSet resultSet = statement.executeQuery()) {
            assertThat(resultSet.next()).isTrue();
            return resultSet.getString(1);
        }
    }
}
