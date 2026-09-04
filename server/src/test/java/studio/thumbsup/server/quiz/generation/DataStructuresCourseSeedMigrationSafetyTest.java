package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.FlywayException;
import org.flywaydb.core.api.MigrationVersion;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import studio.thumbsup.server.common.support.MigrationTestSupport;

/** #320 자료구조 시드의 증분 적용·재실행·중복 코스 가드를 실제 MySQL에서 검증한다. */
class DataStructuresCourseSeedMigrationSafetyTest extends MigrationTestSupport {

    private static final String PREVIOUS_VERSION = "20260905030544";
    private static final String CANDIDATE_VERSION = "20260905042909";

    @TempDir
    Path temporaryMigrationDirectory;

    @Test
    @DisplayName("직전 버전까지 적용한 DB에 한 번만 적용된다")
    void applies_once_to_previous_version_database() throws SQLException {
        flywayAt(PREVIOUS_VERSION).load().migrate();
        assertThat(queryCount("SELECT COUNT(*) FROM flyway_schema_history WHERE success = 1"))
                .isEqualTo(45);

        assertThat(flywayAt(CANDIDATE_VERSION).load().migrate().migrationsExecuted)
                .isOne();
        assertThat(flywayAt(CANDIDATE_VERSION).load().migrate().migrationsExecuted)
                .isZero();

        assertThat(queryCount("SELECT COUNT(*) FROM flyway_schema_history WHERE success = 1"))
                .isEqualTo(46);
        assertThat(queryCount("""
                SELECT COUNT(*)
                FROM flyway_schema_history
                WHERE version = '20260905042909' AND success = 1
                """)).isOne();
    }

    @Test
    @DisplayName("같은 제목의 코스가 있으면 일부 콘텐츠도 추가하지 않고 실패한다")
    void fails_before_inserting_when_course_title_already_exists() throws SQLException {
        flywayAt(PREVIOUS_VERSION).load().migrate();
        execute("""
                INSERT INTO course (title, category, created_at, updated_at)
                VALUES ('자료구조', 'CS', NOW(6), NOW(6))
                """);

        assertThatThrownBy(() -> flywayAt(CANDIDATE_VERSION).load().migrate()).isInstanceOf(FlywayException.class);

        assertThat(queryCount("SELECT COUNT(*) FROM course WHERE title = '자료구조'"))
                .isOne();
        assertThat(queryCount("""
                SELECT COUNT(*)
                FROM quiz_step qs
                JOIN course c ON c.id = qs.course_id
                WHERE c.title = '자료구조'
                """)).isZero();
        assertThat(queryCount("""
                SELECT COUNT(*)
                FROM flyway_schema_history
                WHERE version = '20260905042909' AND success = 1
                """)).isZero();
    }

    @Test
    @DisplayName("후반 SQL이 실패하면 Flyway 이력과 자료구조 코스 전체를 롤백한다")
    void rolls_back_the_complete_course_when_a_late_statement_fails() throws IOException, SQLException {
        flywayAt(PREVIOUS_VERSION).load().migrate();
        String resourcePath = "db/migration/V20260905042909__seed_data_structures_course.sql";
        String candidateSql;
        try (var input = getClass().getClassLoader().getResourceAsStream(resourcePath)) {
            assertThat(input).isNotNull();
            candidateSql = new String(input.readAllBytes(), StandardCharsets.UTF_8);
        }
        String forcedFailureSql = candidateSql.replace("DROP TEMPORARY TABLE data_structures_seed_guard;", """
                DROP TEMPORARY TABLE data_structures_seed_guard;
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'forced rollback';
                """);
        assertThat(forcedFailureSql).contains("forced rollback");
        Files.writeString(
                temporaryMigrationDirectory.resolve("V20260905042909__seed_data_structures_course.sql"),
                forcedFailureSql);

        Flyway failingFlyway = Flyway.configure()
                .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
                .locations("filesystem:" + temporaryMigrationDirectory.toAbsolutePath())
                .validateOnMigrate(false)
                .load();

        assertThatThrownBy(failingFlyway::migrate).isInstanceOf(FlywayException.class);
        assertThat(queryCount("SELECT COUNT(*) FROM course WHERE title = '자료구조'"))
                .isZero();
        assertThat(queryCount("""
                SELECT COUNT(*)
                FROM flyway_schema_history
                WHERE version = '20260905042909' AND success = 1
                """)).isZero();
    }

    private org.flywaydb.core.api.configuration.FluentConfiguration flywayAt(String version) {
        return Flyway.configure()
                .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
                .locations("classpath:db/migration")
                .target(MigrationVersion.fromVersion(version));
    }

    private void execute(String sql) throws SQLException {
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(sql)) {
            assertThat(statement.executeUpdate()).isOne();
        }
    }

    private int queryCount(String sql) throws SQLException {
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(sql);
                ResultSet resultSet = statement.executeQuery()) {
            assertThat(resultSet.next()).isTrue();
            return resultSet.getInt(1);
        }
    }
}
