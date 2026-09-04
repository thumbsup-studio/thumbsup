package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.FlywayException;
import org.flywaydb.core.api.MigrationVersion;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import studio.thumbsup.server.common.support.MigrationTestSupport;

/** #299 라이브 스텝 브리핑 백필의 대상·수량·블록 순서를 실제 MySQL에서 검증한다. */
class QuizStepBriefingBackfillMigrationSafetyTest extends MigrationTestSupport {

    private static final int LIVE_STEP_COUNT = 60;

    @Nested
    @DisplayName("승인된 브리핑 백필")
    class BackfillApprovedBriefings {

        @Test
        @DisplayName("모든 라이브 스텝에 브리핑 하나와 1부터 연속된 블록을 백필한다")
        void backfills_one_briefing_with_continuous_blocks_for_every_live_step() throws SQLException {
            flyway().target(MigrationVersion.fromVersion("20260818232213"))
                    .load()
                    .migrate();

            flyway().load().migrate();

            assertThat(queryCount("SELECT COUNT(*) FROM quiz_step WHERE step_order > 0"))
                    .isEqualTo(LIVE_STEP_COUNT);
            assertThat(queryCount("""
                    SELECT COUNT(*)
                    FROM (
                        SELECT qs.id
                        FROM quiz_step qs
                        LEFT JOIN quiz_step_briefing qsb ON qsb.quiz_step_id = qs.id
                        WHERE qs.step_order > 0
                        GROUP BY qs.id
                        HAVING COUNT(DISTINCT qsb.id) <> 1
                    ) invalid_steps
                    """)).isZero();
            assertThat(queryCount("""
                    SELECT COUNT(*)
                    FROM (
                        SELECT qsb.id
                        FROM quiz_step qs
                        JOIN quiz_step_briefing qsb ON qsb.quiz_step_id = qs.id
                        LEFT JOIN quiz_step_briefing_block qsbb ON qsbb.briefing_id = qsb.id
                        WHERE qs.step_order > 0
                        GROUP BY qsb.id
                        HAVING COUNT(qsbb.id) NOT BETWEEN 2 AND 4
                            OR MIN(qsbb.display_order) <> 1
                            OR MAX(qsbb.display_order) <> COUNT(qsbb.id)
                    ) invalid_briefings
                    """)).isZero();
        }
    }

    @Nested
    @DisplayName("운영 데이터 불일치 가드")
    class SourceGuard {

        @Test
        @DisplayName("기존 스텝 주제가 달라지면 일부만 백필하지 않고 전체 적용을 실패시킨다")
        void fails_instead_of_silently_skipping_a_drifted_step() throws SQLException {
            flyway().target(MigrationVersion.fromVersion("20260818232213"))
                    .load()
                    .migrate();
            execute("""
                    UPDATE quiz_step
                    SET topic = '운영에서 변경한 스텝 주제'
                    WHERE topic = 'OS 개요와 역할(커널·시스템콜·인터럽트)'
                    """);

            org.assertj.core.api.Assertions.assertThatThrownBy(
                            () -> flyway().load().migrate())
                    .isInstanceOf(FlywayException.class);
            assertThat(queryCount("SELECT COUNT(*) FROM quiz_step_briefing")).isZero();
        }
    }

    private org.flywaydb.core.api.configuration.FluentConfiguration flyway() {
        return Flyway.configure()
                .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
                .locations("classpath:db/migration");
    }

    private int queryCount(String sql) throws SQLException {
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(sql);
                ResultSet resultSet = statement.executeQuery()) {
            assertThat(resultSet.next()).isTrue();
            return resultSet.getInt(1);
        }
    }

    private void execute(String sql) throws SQLException {
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(sql)) {
            assertThat(statement.executeUpdate()).isOne();
        }
    }
}
