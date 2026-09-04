package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.FlywayException;
import org.flywaydb.core.api.MigrationVersion;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import studio.thumbsup.server.common.support.MigrationTestSupport;

/** #319 컴퓨터 구조 시드의 증분 적용·재실행·중복 코스 가드를 실제 MySQL에서 검증한다. */
class ComputerArchitectureCourseSeedMigrationSafetyTest extends MigrationTestSupport {

    private static final String PREVIOUS_VERSION = "20260904174004";
    private static final String CANDIDATE_VERSION = "20260905030544";

    @Test
    @DisplayName("직전 버전까지 적용한 DB에 한 번만 적용된다")
    void applies_once_to_previous_version_database() throws SQLException {
        flywayAt(PREVIOUS_VERSION).load().migrate();
        assertThat(queryCount("SELECT COUNT(*) FROM flyway_schema_history WHERE success = 1"))
                .isEqualTo(44);

        assertThat(flywayAt(CANDIDATE_VERSION).load().migrate().migrationsExecuted)
                .isOne();
        assertThat(flywayAt(CANDIDATE_VERSION).load().migrate().migrationsExecuted)
                .isZero();

        assertThat(queryCount("SELECT COUNT(*) FROM flyway_schema_history WHERE success = 1"))
                .isEqualTo(45);
        assertThat(queryCount("""
                SELECT COUNT(*)
                FROM flyway_schema_history
                WHERE version = '20260905030544' AND success = 1
                """)).isOne();
    }

    @Test
    @DisplayName("같은 제목의 코스가 있으면 일부 콘텐츠도 추가하지 않고 실패한다")
    void fails_before_inserting_when_course_title_already_exists() throws SQLException {
        flywayAt(PREVIOUS_VERSION).load().migrate();
        execute("""
                INSERT INTO course (title, category, created_at, updated_at)
                VALUES ('컴퓨터 구조', 'CS', NOW(6), NOW(6))
                """);

        assertThatThrownBy(() -> flywayAt(CANDIDATE_VERSION).load().migrate()).isInstanceOf(FlywayException.class);

        assertThat(queryCount("SELECT COUNT(*) FROM course WHERE title = '컴퓨터 구조'"))
                .isOne();
        assertThat(queryCount("""
                SELECT COUNT(*)
                FROM quiz_step qs
                JOIN course c ON c.id = qs.course_id
                WHERE c.title = '컴퓨터 구조'
                """)).isZero();
        assertThat(queryCount("""
                SELECT COUNT(*)
                FROM flyway_schema_history
                WHERE version = '20260905030544' AND success = 1
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
