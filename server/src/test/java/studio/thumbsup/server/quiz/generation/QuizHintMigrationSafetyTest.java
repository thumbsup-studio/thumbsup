package studio.thumbsup.server.quiz.generation;

import static org.assertj.core.api.Assertions.assertThat;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationVersion;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import studio.thumbsup.server.common.support.MigrationTestSupport;

/** #193 점진 백필이 운영에서 추가·수정된 문제를 보존하는지 실제 MySQL에서 검증한다. */
class QuizHintMigrationSafetyTest extends MigrationTestSupport {

    private static final int DRIFTED_STEP = 14;
    private static final int DRIFTED_SLOT = 5;
    private static final int EXTRA_STEP = 0;
    private static final int EXTRA_SLOT = 99;

    @Test
    @DisplayName("추가·수정·승인 개선된 운영 문제를 보존하고 exact-match canonical 문제만 백필한다")
    void preserves_extra_modified_and_approved_improve_rows_while_backfilling_exact_matches() throws SQLException {
        flyway().target(MigrationVersion.fromVersion("20260728170200")).load().migrate();
        execute("""
                UPDATE quiz
                SET question_text = CONCAT(question_text, ' [drift]')
                WHERE step_order = 14 AND slot_order = 5
                """);
        execute("""
                INSERT INTO quiz
                    (type, difficulty, question_text, code_snippet, correct_answer,
                     explanation_summary, explanation_example, wrong_answer_explanation,
                     step_order, slot_order, created_at, updated_at)
                SELECT type, difficulty, '운영에서 추가한 문제', code_snippet, correct_answer,
                       explanation_summary, explanation_example, wrong_answer_explanation,
                       0, 99, created_at, updated_at
                FROM quiz
                WHERE step_order = 0 AND slot_order = 1
                """);
        execute("""
                INSERT INTO quiz_draft
                    (origin, status, topic, source_quiz_id, current_payload, created_by,
                     approved_by, approved_at, created_at, updated_at)
                SELECT 'IMPROVE', 'APPROVED', '운영 개선', id, '{}', 1,
                       1, NOW(6), NOW(6), NOW(6)
                FROM quiz
                WHERE step_order = 14 AND slot_order = 4
                """);

        flyway().load().migrate();

        assertThat(queryString(DRIFTED_STEP, DRIFTED_SLOT, "question_text")).endsWith(" [drift]");
        assertThat(queryString(DRIFTED_STEP, DRIFTED_SLOT, "hint")).isNull();
        assertThat(queryString(EXTRA_STEP, EXTRA_SLOT, "question_text")).isEqualTo("운영에서 추가한 문제");
        assertThat(queryString(EXTRA_STEP, EXTRA_SLOT, "hint")).isNull();
        assertThat(queryString(14, 4, "hint")).isNull();
        assertThat(queryString(14, 3, "hint")).isNotBlank();
        assertThat(queryString(11, 2, "question_text"))
                .isEqualTo("유닉스 계열의 계층형 이름 공간에서는 하나의 파일이 반드시 하나의 경로로만 접근 가능하므로, 같은 파일을 여러 디렉터리에서 공유할 수 없다.");
        // 73(70 커리큘럼 + placeholder 3) + 이 테스트가 수동 삽입한 1 - #287 정리 마이그레이션이 지우는 placeholder 3 = 71
        assertThat(queryCount("SELECT COUNT(*) FROM quiz")).isEqualTo(71);
    }

    private org.flywaydb.core.api.configuration.FluentConfiguration flyway() {
        return Flyway.configure()
                .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
                .locations("classpath:db/migration");
    }

    private void execute(String sql) throws SQLException {
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(sql)) {
            assertThat(statement.executeUpdate()).isOne();
        }
    }

    private String queryString(int stepOrder, int slotOrder, String column) throws SQLException {
        String sql = "SELECT %s FROM quiz WHERE step_order = ? AND slot_order = ?".formatted(column);
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setInt(1, stepOrder);
            statement.setInt(2, slotOrder);
            try (ResultSet resultSet = statement.executeQuery()) {
                assertThat(resultSet.next()).isTrue();
                return resultSet.getString(1);
            }
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
