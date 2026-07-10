package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.sql.DataSource;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Import;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.config.ClockConfig;
import studio.thumbsup.server.common.config.JpaAuditingConfig;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@Import({ClockConfig.class, JpaAuditingConfig.class})
@ActiveProfiles("test")
class QuizFollowUpMarkerMigrationTest {

    private static final Pattern HIGHLIGHT_MARKER_PATTERN = Pattern.compile("\\[\\[([^\\[\\]]+)\\]\\]");
    private static final String MIGRATION_PATH = "db/migration/V20260711135000__dedupe_follow_up_highlight_markers.sql";
    private static final int BASELINE_DETAILED_FOLLOW_UP_COUNT = 123;
    private static final int BASELINE_FOLLOW_UP_KEYWORD_COUNT = 420;
    private static final long ONE_LINE_PRIORITY_ID = 9_162_001L;
    private static final long BLOCK_PRIORITY_ID = 9_162_002L;
    private static final long NULL_DETAIL_ID = 9_162_003L;
    private static final long EARLIER_ORDER_BLOCK_ID = 9_162_012L;
    private static final long LATER_ORDER_BLOCK_ID = 9_162_011L;

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final DataSource dataSource;
    private final JdbcTemplate jdbcTemplate;

    QuizFollowUpMarkerMigrationTest(@Autowired DataSource dataSource) {
        this.dataSource = dataSource;
        this.jdbcTemplate = new JdbcTemplate(dataSource);
    }

    @Nested
    @DisplayName("전체 시드 검수")
    class SeedAudit {

        @Test
        @DisplayName("시드된 모든 꼬리질문은 등록 키워드를 질문 전체에서 정확히 한 번만 마킹한다")
        void marks_each_seeded_keyword_once_across_the_whole_follow_up_question() {
            Map<Long, Set<String>> dictionaries = loadDictionaries();
            assertThat(dictionaries).hasSizeGreaterThanOrEqualTo(BASELINE_DETAILED_FOLLOW_UP_COUNT);
            assertThat(dictionaries.values().stream().mapToInt(Set::size).sum())
                    .isGreaterThanOrEqualTo(BASELINE_FOLLOW_UP_KEYWORD_COUNT);

            Map<Long, Map<String, Integer>> markerCounts = new HashMap<>();
            List<String> unregisteredMarkers = new ArrayList<>();
            List<String> malformedFields = new ArrayList<>();

            collectMarkerFields("""
                    SELECT id AS follow_up_question_id,
                           'one_line_answer' AS field_name,
                           one_line_answer AS content
                    FROM quiz_follow_up_question
                    WHERE one_line_answer IS NOT NULL
                    ORDER BY id
                    """, dictionaries, markerCounts, unregisteredMarkers, malformedFields);
            collectMarkerFields("""
                    SELECT follow_up_question_id,
                           CONCAT('blocks[', display_order, '].content') AS field_name,
                           content
                    FROM quiz_follow_up_block
                    ORDER BY follow_up_question_id, display_order, id
                    """, dictionaries, markerCounts, unregisteredMarkers, malformedFields);

            assertMarkerAudit(dictionaries, markerCounts, unregisteredMarkers, malformedFields);
        }
    }

    @Nested
    @DisplayName("재실행 안전성")
    class RerunSafety {

        @Test
        @Transactional(propagation = Propagation.NOT_SUPPORTED)
        @DisplayName("마이그레이션은 exact 우선순위와 표시 평문을 지키며 안전하게 재실행된다")
        void rewrites_synthetic_edge_cases_and_is_idempotent() {
            deleteSyntheticFixtures();
            insertSyntheticFixtures();

            try {
                Map<Long, Map<String, String>> visibleTextBefore = loadVisibleTexts();

                rerunMigration();

                assertThat(loadVisibleTexts()).isEqualTo(visibleTextBefore);
                assertThat(oneLineAnswer(ONE_LINE_PRIORITY_ID))
                        .isEqualTo("앞 [[pcb]] 미등록 / 첫 [[PCB]] / 뒤 PCB / 악센트 [[cafe]] 미등록 / 첫 [[café]] / 뒤 café");
                assertThat(blockContent(9_162_021L)).isEqualTo("블록 PCB / café");

                assertThat(oneLineAnswer(BLOCK_PRIORITY_ID)).isEqualTo("평문 답");
                assertThat(blockContent(EARLIER_ORDER_BLOCK_ID)).isEqualTo("일 [[FIFO]] 중 FIFO");
                assertThat(blockContent(LATER_ORDER_BLOCK_ID)).isEqualTo("이 FIFO");

                assertThat(oneLineAnswer(NULL_DETAIL_ID)).isNull();
                assertThat(blockCount(NULL_DETAIL_ID)).isZero();

                Map<String, String> afterFirstRun = loadRawTexts();
                rerunMigration();

                assertThat(loadRawTexts()).isEqualTo(afterFirstRun);
                assertThat(helperTableCount()).isZero();
            } finally {
                deleteSyntheticFixtures();
            }
        }
    }

    private Map<Long, Set<String>> loadDictionaries() {
        Map<Long, Set<String>> dictionaries = new HashMap<>();
        jdbcTemplate.query(
                "SELECT follow_up_question_id, keyword FROM quiz_follow_up_keyword ORDER BY id", resultSet -> {
                    dictionaries
                            .computeIfAbsent(resultSet.getLong("follow_up_question_id"), ignored -> new HashSet<>())
                            .add(resultSet.getString("keyword"));
                });
        return dictionaries;
    }

    private void collectMarkerFields(
            String sql,
            Map<Long, Set<String>> dictionaries,
            Map<Long, Map<String, Integer>> markerCounts,
            List<String> unregisteredMarkers,
            List<String> malformedFields) {
        jdbcTemplate.query(sql, resultSet -> {
            long followUpQuestionId = resultSet.getLong("follow_up_question_id");
            String fieldName = resultSet.getString("field_name");
            collectMarkerState(
                    followUpQuestionId,
                    fieldName,
                    resultSet.getString("content"),
                    dictionaries.getOrDefault(followUpQuestionId, Set.of()),
                    markerCounts,
                    unregisteredMarkers,
                    malformedFields);
        });
    }

    private void insertSyntheticFixtures() {
        Long sourceQuizId = jdbcTemplate.queryForObject("SELECT MIN(id) FROM quiz", Long.class);

        insertOneLinePriorityFixture(sourceQuizId);
        insertBlockPriorityFixture(sourceQuizId);
        insertNullDetailFixture(sourceQuizId);
    }

    private void insertOneLinePriorityFixture(Long sourceQuizId) {

        jdbcTemplate.update("""
                INSERT INTO quiz_follow_up_question
                    (id, quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
                VALUES (?, ?, 'exact 우선순위 테스트', b'0', 9162001, 'MEDIUM',
                        '앞 [[pcb]] 미등록 / 첫 [[PCB]] / 뒤 [[PCB]] / 악센트 [[cafe]] 미등록 / 첫 [[café]] / 뒤 [[café]]')
                """, ONE_LINE_PRIORITY_ID, sourceQuizId);
        jdbcTemplate.update("""
                INSERT INTO quiz_follow_up_keyword
                    (follow_up_question_id, keyword, description)
                VALUES (?, 'PCB', '프로세스 제어 블록'),
                       (?, 'café', '악센트 exact 비교용 키워드')
                """, ONE_LINE_PRIORITY_ID, ONE_LINE_PRIORITY_ID);
        jdbcTemplate.update("""
                INSERT INTO quiz_follow_up_block
                    (id, follow_up_question_id, label, type, content, display_order)
                VALUES (9162021, ?, '해설', 'TEXT', '블록 [[PCB]] / [[café]]', 1)
                """, ONE_LINE_PRIORITY_ID);
    }

    private void insertBlockPriorityFixture(Long sourceQuizId) {
        jdbcTemplate.update("""
                INSERT INTO quiz_follow_up_question
                    (id, quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
                VALUES (?, ?, '블록 순서 테스트', b'0', 9162002, 'MEDIUM', '평문 답')
                """, BLOCK_PRIORITY_ID, sourceQuizId);
        jdbcTemplate.update("""
                INSERT INTO quiz_follow_up_keyword
                    (follow_up_question_id, keyword, description)
                VALUES (?, 'FIFO', '먼저 들어온 값이 먼저 나오는 순서')
                """, BLOCK_PRIORITY_ID);
        // id가 더 작은 display_order=2 블록을 먼저 넣어, keeper가 id가 아니라 표시 순서를 따르는지 검증한다.
        jdbcTemplate.update("""
                INSERT INTO quiz_follow_up_block
                    (id, follow_up_question_id, label, type, content, display_order)
                VALUES (?, ?, '후순위', 'TEXT', '이 [[FIFO]]', 2)
                """, LATER_ORDER_BLOCK_ID, BLOCK_PRIORITY_ID);
        jdbcTemplate.update("""
                INSERT INTO quiz_follow_up_block
                    (id, follow_up_question_id, label, type, content, display_order)
                VALUES (?, ?, '선순위', 'TEXT', '일 [[FIFO]] 중 [[FIFO]]', 1)
                """, EARLIER_ORDER_BLOCK_ID, BLOCK_PRIORITY_ID);
    }

    private void insertNullDetailFixture(Long sourceQuizId) {
        jdbcTemplate.update("""
                INSERT INTO quiz_follow_up_question
                    (id, quiz_id, content, is_primary, display_order, difficulty, one_line_answer)
                VALUES (?, ?, '상세 없는 질문', b'0', 9162003, NULL, NULL)
                """, NULL_DETAIL_ID, sourceQuizId);
        jdbcTemplate.update("""
                INSERT INTO quiz_follow_up_keyword
                    (follow_up_question_id, keyword, description)
                VALUES (?, 'MISSING', '본문에 마커가 없는 사전 항목')
                """, NULL_DETAIL_ID);
    }

    private void assertMarkerAudit(
            Map<Long, Set<String>> dictionaries,
            Map<Long, Map<String, Integer>> markerCounts,
            List<String> unregisteredMarkers,
            List<String> malformedFields) {
        List<String> missingMarkers = new ArrayList<>();
        List<String> duplicatedMarkers = new ArrayList<>();
        dictionaries.forEach((followUpQuestionId, keywords) -> keywords.forEach(keyword -> {
            int count = markerCounts.getOrDefault(followUpQuestionId, Map.of()).getOrDefault(keyword, 0);
            if (count == 0) {
                missingMarkers.add(followUpQuestionId + ": [[" + keyword + "]] 0회");
            } else if (count > 1) {
                duplicatedMarkers.add(followUpQuestionId + ": [[" + keyword + "]] " + count + "회");
            }
        }));

        assertThat(unregisteredMarkers).as("미등록 마커").isEmpty();
        assertThat(malformedFields).as("깨진 마커 필드").isEmpty();
        assertThat(missingMarkers).as("누락 등록 키워드").isEmpty();
        assertThat(duplicatedMarkers)
                .as("질문 전체에서 중복된 등록 키워드: %d개", duplicatedMarkers.size())
                .isEmpty();
    }

    private Map<Long, Map<String, String>> loadVisibleTexts() {
        Map<Long, Map<String, String>> result = new LinkedHashMap<>();
        for (long followUpQuestionId : syntheticQuestionIds()) {
            Set<String> dictionary = new HashSet<>(jdbcTemplate.queryForList(
                    "SELECT keyword FROM quiz_follow_up_keyword WHERE follow_up_question_id = ? ORDER BY id",
                    String.class,
                    followUpQuestionId));
            Map<String, String> fields = new LinkedHashMap<>();
            String oneLineAnswer = oneLineAnswer(followUpQuestionId);
            fields.put(
                    "one_line_answer",
                    oneLineAnswer == null
                            ? null
                            : ExplanationTextParser.parse(oneLineAnswer, dictionary)
                                    .text());
            jdbcTemplate.query(
                    """
                    SELECT id, content
                    FROM quiz_follow_up_block
                    WHERE follow_up_question_id = ?
                    ORDER BY display_order, id
                    """,
                    resultSet -> {
                        fields.put(
                                "block:" + resultSet.getLong("id"),
                                ExplanationTextParser.parse(resultSet.getString("content"), dictionary)
                                        .text());
                    },
                    followUpQuestionId);
            result.put(followUpQuestionId, fields);
        }
        return result;
    }

    private Map<String, String> loadRawTexts() {
        Map<String, String> result = new LinkedHashMap<>();
        for (long followUpQuestionId : syntheticQuestionIds()) {
            result.put("answer:" + followUpQuestionId, oneLineAnswer(followUpQuestionId));
        }
        jdbcTemplate.query(
                """
                SELECT id, content
                FROM quiz_follow_up_block
                WHERE follow_up_question_id IN (?, ?, ?)
                ORDER BY id
                """,
                resultSet -> {
                    result.put("block:" + resultSet.getLong("id"), resultSet.getString("content"));
                },
                ONE_LINE_PRIORITY_ID,
                BLOCK_PRIORITY_ID,
                NULL_DETAIL_ID);
        return result;
    }

    private String oneLineAnswer(long followUpQuestionId) {
        return jdbcTemplate.queryForObject(
                "SELECT one_line_answer FROM quiz_follow_up_question WHERE id = ?", String.class, followUpQuestionId);
    }

    private String blockContent(long blockId) {
        return jdbcTemplate.queryForObject(
                "SELECT content FROM quiz_follow_up_block WHERE id = ?", String.class, blockId);
    }

    private long blockCount(long followUpQuestionId) {
        return jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM quiz_follow_up_block WHERE follow_up_question_id = ?",
                Long.class,
                followUpQuestionId);
    }

    private long helperTableCount() {
        return jdbcTemplate.queryForObject("""
                SELECT COUNT(*)
                FROM information_schema.tables
                WHERE table_schema = DATABASE()
                  AND table_name = 'migration_20260711135000_follow_up_marker'
                """, Long.class);
    }

    private void rerunMigration() {
        ResourceDatabasePopulator populator = new ResourceDatabasePopulator(new ClassPathResource(MIGRATION_PATH));
        populator.execute(dataSource);
    }

    private void deleteSyntheticFixtures() {
        jdbcTemplate.update(
                "DELETE FROM quiz_follow_up_question WHERE id IN (?, ?, ?)",
                ONE_LINE_PRIORITY_ID,
                BLOCK_PRIORITY_ID,
                NULL_DETAIL_ID);
    }

    private long[] syntheticQuestionIds() {
        return new long[] {ONE_LINE_PRIORITY_ID, BLOCK_PRIORITY_ID, NULL_DETAIL_ID};
    }

    private void collectMarkerState(
            long followUpQuestionId,
            String fieldName,
            String content,
            Set<String> registeredKeywords,
            Map<Long, Map<String, Integer>> markerCounts,
            List<String> unregisteredMarkers,
            List<String> malformedFields) {
        Matcher matcher = HIGHLIGHT_MARKER_PATTERN.matcher(content);
        while (matcher.find()) {
            String keyword = matcher.group(1);
            if (!registeredKeywords.contains(keyword)) {
                unregisteredMarkers.add(followUpQuestionId + "/" + fieldName + ": [[" + keyword + "]]");
            } else {
                markerCounts
                        .computeIfAbsent(followUpQuestionId, ignored -> new HashMap<>())
                        .merge(keyword, 1, Integer::sum);
            }
        }

        String withoutCompleteMarkers =
                HIGHLIGHT_MARKER_PATTERN.matcher(content).replaceAll("");
        if (withoutCompleteMarkers.contains("[[") || withoutCompleteMarkers.contains("]]")) {
            malformedFields.add(followUpQuestionId + "/" + fieldName);
        }
    }
}
