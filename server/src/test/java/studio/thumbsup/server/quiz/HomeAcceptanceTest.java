package studio.thumbsup.server.quiz;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.http.HttpHeaders;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.security.JwtTokenProvider;
import studio.thumbsup.server.quiz.course.Course;
import studio.thumbsup.server.quiz.course.CourseRepository;

/**
 * 홈 화면 조회 API 인수 테스트(#240) — 유저가 진행 중인 코스들이 인증 필터체인 + 실제 MySQL을 거쳐
 * "최근 푼 순" 목록으로 조립되는지 검증한다 (피라미드 4층).
 *
 * <p>docs/testing-guide.md §3 기준: 진행·코스·스텝 3개 테이블의 크로스 도메인 조립과 정렬이 함께 맞아야
 * 하는 FE 계약 핵심 흐름이라 인수 층에 둔다. 정렬 tie-break·10개 상한은 {@code QuizProgressRepositoryTest}가,
 * 조립 세부 분기(코스 삭제 skip·clamp)는 {@code HomeServiceTest}가 담당하므로 여기서 반복하지 않는다.
 *
 * <p>스텝은 Flyway 시드 데이터(stepOrder 0~14)·다른 인수 테스트(9000번대 초반)와 겹치지 않도록
 * 9100·9200번대를 쓴다. 유저는 테스트마다 다른 id를 써서 진행 기록이 섞이지 않게 한다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@ActiveProfiles("test")
class HomeAcceptanceTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final MockMvc mockMvc;
    private final ObjectMapper objectMapper;
    private final JwtTokenProvider jwtTokenProvider;
    private final CourseRepository courseRepository;
    private final QuizStepRepository quizStepRepository;
    private final QuizProgressRepository quizProgressRepository;

    HomeAcceptanceTest(
            @Autowired MockMvc mockMvc,
            @Autowired ObjectMapper objectMapper,
            @Autowired JwtTokenProvider jwtTokenProvider,
            @Autowired CourseRepository courseRepository,
            @Autowired QuizStepRepository quizStepRepository,
            @Autowired QuizProgressRepository quizProgressRepository) {
        this.mockMvc = mockMvc;
        this.objectMapper = objectMapper;
        this.jwtTokenProvider = jwtTokenProvider;
        this.courseRepository = courseRepository;
        this.quizStepRepository = quizStepRepository;
        this.quizProgressRepository = quizProgressRepository;
    }

    private String bearerToken(Long userId) {
        return "Bearer " + jwtTokenProvider.createAccessToken(userId);
    }

    @Nested
    @DisplayName("GET /api/v1/home")
    class GetHome {

        @Test
        @DisplayName("여러 코스를 진행 중이면 최근에 푼 코스부터 순서대로 목록을 반환한다")
        void returns_courses_ordered_by_recently_solved() throws Exception {
            Long userId = 901L;
            Long courseA =
                    courseRepository.save(Course.create("홈 인수 코스A", "CS")).getId();
            Long courseB =
                    courseRepository.save(Course.create("홈 인수 코스B", "CS")).getId();
            quizStepRepository.save(QuizStep.create(9101, courseA, "A-스텝1", 5));
            quizStepRepository.save(QuizStep.create(9102, courseA, "A-스텝2", 5));
            quizStepRepository.save(QuizStep.create(9103, courseA, "A-스텝3", 5));
            quizStepRepository.save(QuizStep.create(9201, courseB, "B-스텝1", 5));
            quizStepRepository.save(QuizStep.create(9202, courseB, "B-스텝2", 5));
            // A를 먼저, B를 나중에 저장 — B가 "더 최근에 푼" 코스가 된다 (updatedAt 최신, 동시각이어도 id 역순).
            quizProgressRepository.save(QuizProgress.create(userId, courseA, 9102));
            quizProgressRepository.save(QuizProgress.create(userId, courseB, 9201));

            String responseBody = mockMvc.perform(
                            get("/api/v1/home").header(HttpHeaders.AUTHORIZATION, bearerToken(userId)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andReturn()
                    .getResponse()
                    .getContentAsString(StandardCharsets.UTF_8);

            JsonNode courses = objectMapper.readTree(responseBody).path("data").path("courses");
            assertThat(courses.size()).isEqualTo(2);
            assertThat(courses.get(0).path("courseId").asLong()).isEqualTo(courseB);
            assertThat(courses.get(0).path("courseTitle").asText()).isEqualTo("홈 인수 코스B");
            assertThat(courses.get(0).path("unitTitle").asText()).isEqualTo("B-스텝1");
            assertThat(courses.get(0).path("completedCount").asInt()).isZero();
            assertThat(courses.get(0).path("totalCount").asInt()).isEqualTo(2);
            assertThat(courses.get(1).path("courseId").asLong()).isEqualTo(courseA);
            assertThat(courses.get(1).path("completedCount").asInt()).isEqualTo(1);
            assertThat(courses.get(1).path("totalCount").asInt()).isEqualTo(3);
        }

        @Test
        @DisplayName("진행 중인 코스가 없으면(신규 유저) 첫 번째 코스 하나를 목록에 담아 반환한다")
        void returns_first_course_for_new_user() throws Exception {
            Long userId = 902L;
            Long firstCourseId = courseRepository
                    .findFirstByOrderByIdAsc()
                    .orElseThrow(() -> new AssertionError("시드 코스가 없다"))
                    .getId();

            String responseBody = mockMvc.perform(
                            get("/api/v1/home").header(HttpHeaders.AUTHORIZATION, bearerToken(userId)))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andReturn()
                    .getResponse()
                    .getContentAsString(StandardCharsets.UTF_8);

            JsonNode courses = objectMapper.readTree(responseBody).path("data").path("courses");
            assertThat(courses.size()).isEqualTo(1);
            assertThat(courses.get(0).path("courseId").asLong()).isEqualTo(firstCourseId);
            assertThat(courses.get(0).path("completedCount").asInt()).isZero();
        }

        @Test
        @DisplayName("Authorization 헤더가 없으면 필터체인이 401로 막는다")
        void returns_401_without_token() throws Exception {
            mockMvc.perform(get("/api/v1/home")).andExpect(status().isUnauthorized());
        }
    }
}
