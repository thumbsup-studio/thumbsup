package studio.thumbsup.server.quiz;

import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.test.web.servlet.MockMvc;
import studio.thumbsup.server.common.security.JwtTokenProvider;
import studio.thumbsup.server.common.support.AcceptanceTestSupport;

/** 문제 조회 API 인수 테스트 — Flyway 데이터가 JPA·DTO·필터체인을 거쳐 정확히 노출되는지 검증한다. */
class QuizRetrievalAcceptanceTest extends AcceptanceTestSupport {

    private static final long TEST_USER_ID = 157L;
    private static final long OS_COURSE_ID = 1L;

    private static final List<CorrectedQuiz> CORRECTED_QUIZZES = List.of(
            new CorrectedQuiz(
                    2,
                    "단일 CPU 환경에서 CPU를 사용 중인 프로세스 P에 타이머 인터럽트가 발생했다. "
                            + "P는 종료되거나 입출력을 요청하지 않았으며, 운영체제는 P의 실행 정보를 저장한 뒤 "
                            + "다른 프로세스에 CPU를 넘겼다. 이때 P의 상태 전이로 가장 알맞은 것을 고르시오."),
            new CorrectedQuiz(
                    4,
                    "세 프로세스 P1(우선순위 3), P2(우선순위 1), P3(우선순위 2)가 모두 같은 시각에 준비 상태가 된다. "
                            + "숫자가 작을수록 우선순위가 높으며, 비선점형 우선순위 스케줄링을 사용한다. "
                            + "이 상황에 대한 설명으로 옳은 것을 고르시오."),
            new CorrectedQuiz(
                    5,
                    "프로세스 A(우선순위 3, 버스트 시간 5), B(우선순위 1, 버스트 시간 8), "
                            + "C(우선순위 2, 버스트 시간 2), D(우선순위 4, 버스트 시간 1)가 모두 시각 0에 준비 큐에 있다. "
                            + "숫자가 작을수록 우선순위가 높은 선점형 우선순위 스케줄링을 사용할 때, "
                            + "가장 먼저 CPU를 할당받는 프로세스로 알맞은 것을 고르시오."),
            new CorrectedQuiz(
                    10,
                    "페이지 프레임이 3개이고 페이지 참조열이 [1, 2, 3, 2, 4] 순서로 주어졌을 때, "
                            + "LRU 알고리즘의 설명으로 가장 알맞은 것을 고르시오. 각 숫자는 페이지 번호를 의미한다."));

    private final MockMvc mockMvc;
    private final JwtTokenProvider jwtTokenProvider;
    private final QuizProgressRepository quizProgressRepository;

    QuizRetrievalAcceptanceTest(
            @Autowired MockMvc mockMvc,
            @Autowired JwtTokenProvider jwtTokenProvider,
            @Autowired QuizProgressRepository quizProgressRepository) {
        this.mockMvc = mockMvc;
        this.jwtTokenProvider = jwtTokenProvider;
        this.quizProgressRepository = quizProgressRepository;
    }

    @BeforeEach
    void setUpProgress() {
        QuizProgress progress = quizProgressRepository
                .findByUserIdAndCourseId(TEST_USER_ID, OS_COURSE_ID)
                .orElseGet(() -> QuizProgress.create(TEST_USER_ID, OS_COURSE_ID, 1));
        while (progress.getCurrentStepOrder() < 10) {
            progress.advanceToNextStep();
        }
        quizProgressRepository.saveAndFlush(progress);
    }

    @Nested
    @DisplayName("문제 조회")
    class GetQuiz {

        @Test
        @DisplayName("코드가 아닌 지문 네 문제는 문맥을 본문에 보존하고 codeSnippet을 null로 반환한다")
        void returns_corrected_text_without_code_snippet() throws Exception {
            for (CorrectedQuiz expected : CORRECTED_QUIZZES) {
                mockMvc.perform(get("/api/v1/quizzes/steps/{stepOrder}/4", expected.stepOrder())
                                .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                        .andExpect(status().isOk())
                        .andExpect(jsonPath("$.data.questionText").value(expected.questionText()))
                        .andExpect(jsonPath("$.data.codeSnippet").value(nullValue()));
            }
        }

        @Test
        @DisplayName("실제 코드 지문이 있는 문제는 기존 코드 지문을 그대로 반환한다")
        void keeps_real_code_snippet() throws Exception {
            mockMvc.perform(get("/api/v1/quizzes/steps/1/4").header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.codeSnippet").value(org.hamcrest.Matchers.containsString("open(")));
        }
    }

    private String bearerToken() {
        return "Bearer " + jwtTokenProvider.createAccessToken(TEST_USER_ID);
    }

    private record CorrectedQuiz(int stepOrder, String questionText) {}
}
