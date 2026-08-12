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
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import studio.thumbsup.server.common.support.MigrationTestSupport;

/** #157 보정 마이그레이션의 원문 guard와 트랜잭션 롤백을 실제 MySQL에서 검증한다. */
class QuizSnippetMigrationSafetyTest extends MigrationTestSupport {

    private static final String ORIGINAL_STEP_2_QUESTION = "다음 설명에 가장 알맞은 상태 전이를 고르시오.";
    private static final String ORIGINAL_STEP_2_SNIPPET = """
            // 단일 CPU 환경 가정
            프로세스 P가 현재 CPU에서 실행 중이다.
            타이머 인터럽트가 발생했고,
            운영체제는 P의 실행 정보를 저장한 뒤
            다른 프로세스에게 CPU를 넘긴다.""";

    @Nested
    @DisplayName("원문 guard")
    class GuardedPatch {

        @Test
        @DisplayName("뒤쪽 대상의 원문이 달라지면 마이그레이션 전체를 실패시키고 앞선 보정도 롤백한다")
        void rolls_back_all_updates_when_source_data_has_drifted() throws SQLException {
            flyway().target(MigrationVersion.fromVersion("20260711110000"))
                    .load()
                    .migrate();
            execute("""
                    UPDATE quiz
                    SET code_snippet = CONCAT(code_snippet, '\n# drift')
                    WHERE step_order = 10 AND slot_order = 4
                    """);

            assertThatThrownBy(() -> flyway().load().migrate()).isInstanceOf(FlywayException.class);

            assertThat(queryStep2("question_text")).isEqualTo(ORIGINAL_STEP_2_QUESTION);
            assertThat(queryStep2("code_snippet")).isEqualTo(ORIGINAL_STEP_2_SNIPPET);
        }
    }

    private org.flywaydb.core.api.configuration.FluentConfiguration flyway() {
        return Flyway.configure()
                .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
                .locations("classpath:db/migration");
    }

    private void execute(String sql) throws SQLException {
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(sql)) {
            statement.executeUpdate();
        }
    }

    private String queryStep2(String column) throws SQLException {
        String sql = "SELECT %s FROM quiz WHERE step_order = 2 AND slot_order = 4".formatted(column);
        try (Connection connection = MYSQL.createConnection("");
                PreparedStatement statement = connection.prepareStatement(sql);
                ResultSet resultSet = statement.executeQuery()) {
            assertThat(resultSet.next()).isTrue();
            return resultSet.getString(1);
        }
    }
}
