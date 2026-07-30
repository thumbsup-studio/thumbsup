package studio.thumbsup.server.quiz.course;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.util.stream.StreamSupport;
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
import studio.thumbsup.server.quiz.QuizProgress;
import studio.thumbsup.server.quiz.QuizProgressRepository;
import studio.thumbsup.server.quiz.QuizStep;
import studio.thumbsup.server.quiz.QuizStepRepository;

/**
 * 코스 목록 조회 API 인수 테스트 — 코스·스텝·진행 커서가 인증 필터체인 + 실제 MySQL을 거쳐 스텝 상태로
 * 정확히 조립되는지 검증한다 (피라미드 4층).
 *
 * <p>docs/testing-guide.md §3 기준: 인증 필터체인 통과 + 코스·스텝·진행 3개 테이블의 크로스 도메인 조립이
 * 함께 맞아야 하는 핵심 흐름이라 인수 층에 둔다. 커서 계산 세부 분기는 {@code CourseServiceTest}가,
 * envelope 형태는 {@code CourseControllerTest}가 담당하므로 여기서 반복하지 않는다.
 *
 * <p>스텝은 Flyway 시드 데이터(운영체제/디자인패턴, stepOrder 0~14)와 겹치지 않도록 9000번대를 쓴다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@ActiveProfiles("test")
class CourseAcceptanceTest {

    private static final Long USER_ID = 1L;

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final MockMvc mockMvc;
    private final ObjectMapper objectMapper;
    private final JwtTokenProvider jwtTokenProvider;
    private final CourseRepository courseRepository;
    private final QuizStepRepository quizStepRepository;
    private final QuizProgressRepository quizProgressRepository;

    CourseAcceptanceTest(
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

    private String bearerToken() {
        return "Bearer " + jwtTokenProvider.createAccessToken(USER_ID);
    }

    @Nested
    @DisplayName("GET /api/v1/courses")
    class GetCourses {

        @Test
        @DisplayName("코스별 스텝을 진행 커서 기준으로 COMPLETED/SOLVABLE/LOCKED로 분류해 반환한다")
        void returns_courses_with_step_states() throws Exception {
            Long courseId =
                    courseRepository.save(Course.create("코스 목록 인수 테스트", "CS")).getId();
            quizStepRepository.save(QuizStep.create(9001, courseId, "스텝1", 5));
            quizStepRepository.save(QuizStep.create(9002, courseId, "스텝2", 5));
            quizStepRepository.save(QuizStep.create(9003, courseId, "스텝3", 5));
            quizProgressRepository.save(QuizProgress.create(USER_ID, courseId, 9002));

            String responseBody = mockMvc.perform(
                            get("/api/v1/courses").header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andReturn()
                    .getResponse()
                    .getContentAsString(StandardCharsets.UTF_8);

            JsonNode items = objectMapper.readTree(responseBody).path("data").path("items");
            JsonNode myCourse = StreamSupport.stream(items.spliterator(), false)
                    .filter(item -> item.path("courseId").asLong() == courseId)
                    .findFirst()
                    .orElseThrow(() -> new AssertionError("응답에 방금 만든 코스가 없다: " + responseBody));

            assertThat(myCourse.path("title").asText()).isEqualTo("코스 목록 인수 테스트");
            JsonNode steps = myCourse.path("steps");
            assertThat(steps.get(0).path("state").asText()).isEqualTo("COMPLETED");
            assertThat(steps.get(1).path("state").asText()).isEqualTo("SOLVABLE");
            assertThat(steps.get(2).path("state").asText()).isEqualTo("LOCKED");
        }

        @Test
        @DisplayName("Authorization 헤더가 없으면 필터체인이 401로 막는다")
        void returns_401_without_token() throws Exception {
            mockMvc.perform(get("/api/v1/courses")).andExpect(status().isUnauthorized());
        }
    }
}
