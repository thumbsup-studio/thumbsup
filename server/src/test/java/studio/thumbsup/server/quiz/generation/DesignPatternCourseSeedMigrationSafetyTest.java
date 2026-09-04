package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.io.IOException;
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

/** #318 디자인 패턴 확장 시드의 증분 적용·재실행·기준 데이터 불일치 가드를 실제 MySQL에서 검증한다. */
class DesignPatternCourseSeedMigrationSafetyTest extends MigrationTestSupport {

    private static final String PREVIOUS_VERSION = "20260904142250";
    private static final String CANDIDATE_VERSION = "20260904174004";

    @TempDir
    Path temporaryMigrationDirectory;

    @Test
    @DisplayName("직전 버전까지 적용한 DB에 한 번만 적용된다")
    void applies_once_to_previous_version_database() throws SQLException {
        flywayAt(PREVIOUS_VERSION).load().migrate();
        assertThat(queryCount("SELECT COUNT(*) FROM flyway_schema_history WHERE success = 1"))
                .isEqualTo(43);

        assertThat(flywayAt(CANDIDATE_VERSION).load().migrate().migrationsExecuted)
                .isOne();
        assertThat(flywayAt(CANDIDATE_VERSION).load().migrate().migrationsExecuted)
                .isZero();

        assertThat(queryCount("SELECT COUNT(*) FROM flyway_schema_history WHERE success = 1"))
                .isEqualTo(44);
        assertThat(queryCount("""
                SELECT COUNT(*)
                FROM flyway_schema_history
                WHERE version = '20260904174004' AND success = 1
                """)).isOne();
    }

    @Test
    @DisplayName("디자인 패턴에 Flyway 밖 스텝이 있으면 일부 콘텐츠도 추가하지 않고 실패한다")
    void fails_before_inserting_when_live_steps_have_drifted() throws SQLException {
        flywayAt(PREVIOUS_VERSION).load().migrate();
        execute("""
                INSERT INTO quiz_step
                    (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
                SELECT 3, '운영에서 먼저 추가한 스텝', 3, id, NOW(6), NOW(6)
                FROM course
                WHERE title = '디자인 패턴'
                """);

        assertThatThrownBy(() -> flywayAt(CANDIDATE_VERSION).load().migrate()).isInstanceOf(FlywayException.class);

        assertThat(queryCount("""
                SELECT COUNT(*)
                FROM quiz_step qs
                JOIN course c ON c.id = qs.course_id
                WHERE c.title = '디자인 패턴'
                """)).isEqualTo(3);
        assertThat(queryCount("""
                SELECT COUNT(*)
                FROM quiz_step qs
                JOIN course c ON c.id = qs.course_id
                WHERE c.title = '디자인 패턴' AND qs.step_order BETWEEN 4 AND 16
                """)).isZero();
        assertThat(queryCount("""
                SELECT COUNT(*)
                FROM flyway_schema_history
                WHERE version = '20260904174004' AND success = 1
                """)).isZero();
    }

    @Test
    @DisplayName("MySQL에서 임시 테이블을 쓰는 DML 마이그레이션이 실패하면 전체 변경이 롤백된다")
    void rolls_back_all_dml_when_migration_fails_after_temporary_table_is_dropped() throws IOException, SQLException {
        flywayAt(CANDIDATE_VERSION).load().migrate();
        Files.writeString(temporaryMigrationDirectory.resolve("V20260904174005__force_transaction_rollback.sql"), """
                CREATE TEMPORARY TABLE design_pattern_transaction_probe (id INT PRIMARY KEY);
                INSERT INTO design_pattern_transaction_probe (id) VALUES (1);
                INSERT INTO quiz_step
                    (step_order, topic, estimated_minutes, course_id, created_at, updated_at)
                SELECT 17, '롤백 검증용 스텝', 3, id, NOW(6), NOW(6)
                FROM course
                WHERE title = '디자인 패턴';
                DROP TEMPORARY TABLE design_pattern_transaction_probe;
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'forced rollback';
                """);

        Flyway failingFlyway = Flyway.configure()
                .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
                .locations("filesystem:" + temporaryMigrationDirectory.toAbsolutePath())
                .validateOnMigrate(false)
                .load();

        assertThatThrownBy(failingFlyway::migrate).isInstanceOf(FlywayException.class);
        assertThat(queryCount("""
                SELECT COUNT(*)
                FROM quiz_step qs
                JOIN course c ON c.id = qs.course_id
                WHERE c.title = '디자인 패턴'
                """)).isEqualTo(16);
        assertThat(queryCount("""
                SELECT COUNT(*)
                FROM flyway_schema_history
                WHERE version = '20260904174005' AND success = 1
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
