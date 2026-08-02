package studio.thumbsup.server.quiz.history;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.sql.Timestamp;
import java.time.Instant;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.HttpHeaders;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.DatabaseCleanUp;
import studio.thumbsup.server.common.security.JwtTokenProvider;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;
import studio.thumbsup.server.quiz.concept.Concept;
import studio.thumbsup.server.quiz.concept.ConceptDescriptionRepository;
import studio.thumbsup.server.quiz.concept.ConceptFixture;
import studio.thumbsup.server.quiz.concept.ConceptRelationRepository;
import studio.thumbsup.server.quiz.concept.ConceptRepository;
import studio.thumbsup.server.quiz.concept.UserConcept;
import studio.thumbsup.server.quiz.concept.UserConceptRepository;
import studio.thumbsup.server.quiz.concept.UserConceptStep;
import studio.thumbsup.server.quiz.concept.UserConceptStepRepository;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;

/**
 * 지식 그래프 조회 API 인수 테스트 — Concept/ConceptRelation/ConceptDescription 데이터가
 * 인증 필터체인·JPA 매핑을 거쳐 공통 envelope로 정확히 노출되는지 검증한다(#233, 피라미드 4층).
 * Flyway 시드 데이터는 큐레이션이 계속 바뀔 수 있어 의존하지 않고, {@code databaseCleanUp}으로 비운
 * 뒤 이 테스트만의 고정 픽스처를 직접 저장한다(다른 리포지토리 테스트와 동일한 관례).
 *
 * <p>스텝 완료 시 {@code user_concept}/{@code user_concept_step}를 채우는 로직 자체는
 * {@code LearnedConceptRecorderTest}가, description을 스텝 단위로 필터링하는 로직 자체는
 * {@code HistoryServiceTest}가 이미 단위로 검증하므로, 여기서는 그 결과물이 이미 있다고 가정하고
 * 조회 경로(인증·조인·응답 계약·날짜 직렬화)만 검증해 층간 중복을 피한다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@ActiveProfiles("test")
class HistoryGraphAcceptanceTest {

    private static final long TEST_USER_ID = 1L;
    private static final int STEP_ORDER = 6;

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final MockMvc mockMvc;
    private final JwtTokenProvider jwtTokenProvider;
    private final ConceptRepository conceptRepository;
    private final ConceptRelationRepository conceptRelationRepository;
    private final UserConceptRepository userConceptRepository;
    private final UserConceptStepRepository userConceptStepRepository;
    private final DatabaseCleanUp databaseCleanUp;

    // 픽스처 준비(스텝 부모 행 생성, learnedAt 시각 고정)에만 쓰는 주변부 의존성 — 생성자에 추가하면
    // 체크스타일 파라미터 수 상한(7개)을 넘긴다.
    @Autowired
    private ConceptDescriptionRepository conceptDescriptionRepository;

    @Autowired
    private QuizStepRepository quizStepRepository;

    @Autowired
    private CourseRepository courseRepository;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    HistoryGraphAcceptanceTest(
            @Autowired MockMvc mockMvc,
            @Autowired JwtTokenProvider jwtTokenProvider,
            @Autowired ConceptRepository conceptRepository,
            @Autowired ConceptRelationRepository conceptRelationRepository,
            @Autowired UserConceptRepository userConceptRepository,
            @Autowired UserConceptStepRepository userConceptStepRepository,
            @Autowired DatabaseCleanUp databaseCleanUp) {
        this.mockMvc = mockMvc;
        this.jwtTokenProvider = jwtTokenProvider;
        this.conceptRepository = conceptRepository;
        this.conceptRelationRepository = conceptRelationRepository;
        this.userConceptRepository = userConceptRepository;
        this.userConceptStepRepository = userConceptStepRepository;
        this.databaseCleanUp = databaseCleanUp;
    }

    private String bearerToken() {
        return "Bearer " + jwtTokenProvider.createAccessToken(TEST_USER_ID);
    }

    /** user_concept_step·concept_description의 step_order가 quiz_step(→course)을 FK로 참조하므로 부모 행을 만든다. */
    private void saveStep(int stepOrder, String topic) {
        Long courseId = courseRepository.save(Course.create("테스트 코스", "CS")).getId();
        quizStepRepository.save(QuizStep.create(stepOrder, courseId, topic, 10));
    }

    @Nested
    @DisplayName("GET /api/v1/history/graph")
    class GetGraph {

        @Test
        @DisplayName("Authorization 헤더가 없으면 필터체인이 401로 막는다")
        void returns_401_without_token() throws Exception {
            mockMvc.perform(get("/api/v1/history/graph")).andExpect(status().isUnauthorized());
        }

        @Test
        @DisplayName("학습한 개념이 없으면 에러가 아니라 빈 nodes/edges로 응답한다")
        void returns_empty_graph_when_nothing_learned() throws Exception {
            databaseCleanUp.execute();

            mockMvc.perform(get("/api/v1/history/graph").header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.nodes.length()").value(0))
                    .andExpect(jsonPath("$.data.edges.length()").value(0));
        }

        @Test
        @DisplayName("학습한 개념은 상세·완료 스텝의 설명·KST 학습일과 함께, 서로 연결된 것끼리는 엣지로 응답한다")
        void returns_learned_concepts_with_stored_detail_and_edges() throws Exception {
            databaseCleanUp.execute();
            saveStep(STEP_ORDER, "동기화 도구");
            Concept mutualExclusion = conceptRepository.saveAndFlush(ConceptFixture.concept(null, "상호 배제", "동시성"));
            Concept criticalSection = conceptRepository.saveAndFlush(ConceptFixture.concept(null, "임계 구역", "동시성"));
            conceptRelationRepository.save(ConceptFixture.relation(mutualExclusion.getId(), criticalSection.getId()));
            conceptDescriptionRepository.save(ConceptFixture.conceptDescription(
                    mutualExclusion.getId(), "한 시점에 하나의 실행 흐름만 임계구역에 들어가게 하는 성질이다.", STEP_ORDER));

            userConceptRepository.save(UserConcept.create(TEST_USER_ID, mutualExclusion.getId()));
            userConceptRepository.save(UserConcept.create(TEST_USER_ID, criticalSection.getId()));
            userConceptStepRepository.save(UserConceptStep.create(TEST_USER_ID, mutualExclusion.getId(), STEP_ORDER));
            // learnedAt(UTC 저장 → KST 날짜) 경계 검증: UTC 7/8 15:00 = KST 7/9 00:00.
            // createdAt은 auditing이 채우는 updatable=false 성격의 컬럼이라 엔티티로는 못 바꾸므로 SQL로 고정한다.
            jdbcTemplate.update(
                    "UPDATE user_concept SET created_at = ? WHERE user_id = ? AND concept_id = ?",
                    Timestamp.from(Instant.parse("2026-07-08T15:00:00Z")),
                    TEST_USER_ID,
                    mutualExclusion.getId());

            mockMvc.perform(get("/api/v1/history/graph").header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.nodes.length()").value(2))
                    .andExpect(jsonPath("$.data.nodes[?(@.id=='" + mutualExclusion.getId() + "')].label")
                            .value("상호 배제"))
                    .andExpect(jsonPath("$.data.nodes[?(@.id=='" + mutualExclusion.getId() + "')].description[0]")
                            .value("한 시점에 하나의 실행 흐름만 임계구역에 들어가게 하는 성질이다."))
                    .andExpect(jsonPath("$.data.nodes[?(@.id=='" + mutualExclusion.getId() + "')].learnedAt")
                            .value("2026-07-09"))
                    .andExpect(jsonPath("$.data.nodes[?(@.id=='" + mutualExclusion.getId()
                                    + "')].relatedSteps[0].stepOrder")
                            .value(STEP_ORDER))
                    .andExpect(
                            jsonPath("$.data.nodes[?(@.id=='" + mutualExclusion.getId() + "')].relatedSteps[0].topic")
                                    .value("동기화 도구"))
                    .andExpect(jsonPath("$.data.edges[0].source").value(String.valueOf(mutualExclusion.getId())))
                    .andExpect(jsonPath("$.data.edges[0].target").value(String.valueOf(criticalSection.getId())));
        }
    }
}
