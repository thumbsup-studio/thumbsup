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

    // 이 값으로 직접 SQL을 조작하는 시점은 #292 이전(20260728170200)이라 전역 순번을 그대로 쓴다.
    private static final int DRIFTED_STEP = 14;
    private static final int DRIFTED_SLOT = 5;
    // #292가 quiz_step을 코스별 상대 순번으로 재번호하므로, flyway().load()로 전체 마이그레이션을 적용한
    // 뒤(line 53) 조회하는 단언은 디자인 패턴 코스 기준 상대 순번(전역 14 → 코스 상대 2)을 써야 한다.
    // step_order만으로는 OS 코스에도 같은 번호(예: 2)가 존재해 모호하므로 courseId까지 함께 지정한다.
    private static final int DRIFTED_STEP_AFTER_RENUMBERING = 2;
    private static final int EXTRA_STEP = 0;
    private static final int EXTRA_SLOT = 99;
    // 이 마이그레이션 시퀀스에서 코스는 항상 이 순서로 결정된다 — OS는 V20260711100000이 `id=1`로
    // 못박고, 디자인 패턴은 V20260728170100이 그 뒤에 LAST_INSERT_ID()로 만드는 유일한 두 번째 코스다.
    private static final long OS_COURSE_ID = 1L;
    private static final long DESIGN_PATTERN_COURSE_ID = 2L;

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

        assertThat(queryString(DESIGN_PATTERN_COURSE_ID, DRIFTED_STEP_AFTER_RENUMBERING, DRIFTED_SLOT, "question_text"))
                .endsWith(" [drift]");
        assertThat(queryString(DESIGN_PATTERN_COURSE_ID, DRIFTED_STEP_AFTER_RENUMBERING, DRIFTED_SLOT, "hint"))
                .isNull();
        assertThat(queryString(OS_COURSE_ID, EXTRA_STEP, EXTRA_SLOT, "question_text"))
                .isEqualTo("운영에서 추가한 문제");
        assertThat(queryString(OS_COURSE_ID, EXTRA_STEP, EXTRA_SLOT, "hint")).isNull();
        assertThat(queryString(DESIGN_PATTERN_COURSE_ID, DRIFTED_STEP_AFTER_RENUMBERING, 4, "hint"))
                .isNull();
        assertThat(queryString(DESIGN_PATTERN_COURSE_ID, DRIFTED_STEP_AFTER_RENUMBERING, 3, "hint"))
                .isNotBlank();
        assertThat(queryString(OS_COURSE_ID, 11, 2, "question_text"))
                .isEqualTo("유닉스 계열의 계층형 이름 공간에서는 하나의 파일이 반드시 하나의 경로로만 접근 가능하므로, 같은 파일을 여러 디렉터리에서 공유할 수 없다.");
        // 303(기존 70 + 네트워크 80 + 디자인 패턴 확장 70 + 컴퓨터 구조 80 + placeholder 3)
        // + 수동 삽입 1 - #287이 지우는 placeholder 3 = 301
        assertThat(queryCount("SELECT COUNT(*) FROM quiz")).isEqualTo(301);
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

    /**
     * step_order는 코스별 상대 순번이라(#292) 코스가 다르면 같은 값이 겹친다 — quiz_step을 통해
     * courseId까지 함께 지정해야 유일하게 찾을 수 있다.
     */
    private String queryString(long courseId, int stepOrder, int slotOrder, String column) throws SQLException {
        String sql = ("SELECT q.%s FROM quiz q JOIN quiz_step qs ON q.quiz_step_id = qs.id "
                        + "WHERE qs.course_id = ? AND q.step_order = ? AND q.slot_order = ?")
                .formatted(column);
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.setLong(1, courseId);
            statement.setInt(2, stepOrder);
            statement.setInt(3, slotOrder);
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
