package studio.thumbsup.server.quiz.history;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.method.annotation.AuthenticationPrincipalArgumentResolver;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import studio.thumbsup.server.common.exception.GlobalExceptionHandler;
import studio.thumbsup.server.quiz.history.dto.HistoryGraphResponse;
import studio.thumbsup.server.quiz.history.dto.HistoryGraphResponse.Edge;
import studio.thumbsup.server.quiz.history.dto.HistoryGraphResponse.Node;
import studio.thumbsup.server.quiz.history.dto.HistoryGraphResponse.RelatedStep;

/** Controller 슬라이스 테스트 — standalone MockMvc로 요청/응답 계약만 검증한다 (피라미드 2층). */
@ExtendWith(MockitoExtension.class)
@DisplayName("지식 그래프 컨트롤러")
class HistoryControllerTest {

    @Mock
    private HistoryService historyService;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        ObjectMapper objectMapper = new ObjectMapper()
                .registerModule(new JavaTimeModule())
                .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

        mockMvc = MockMvcBuilders.standaloneSetup(new HistoryController(historyService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .setMessageConverters(new MappingJackson2HttpMessageConverter(objectMapper))
                .setCustomArgumentResolvers(new AuthenticationPrincipalArgumentResolver())
                .build();
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    private void authenticateAs(Long userId) {
        SecurityContextHolder.getContext()
                .setAuthentication(new UsernamePasswordAuthenticationToken(userId, null, List.of()));
    }

    @Nested
    @DisplayName("GET /api/v1/history/graph")
    class GetGraph {

        @Test
        @DisplayName("성공하면 200과 nodes/edges를 공통 envelope로 반환한다")
        void returns_200_with_nodes_and_edges() throws Exception {
            authenticateAs(7L);
            Node node = new Node(
                    "1",
                    "프로세스",
                    List.of("실행 중인 프로그램의 인스턴스입니다."),
                    LocalDate.of(2026, 7, 8),
                    "프로세스",
                    List.of(new RelatedStep(1, "프로세스와 스레드")));
            given(historyService.getGraph(eq(7L)))
                    .willReturn(new HistoryGraphResponse(List.of(node), List.of(new Edge("1", "2"))));

            mockMvc.perform(get("/api/v1/history/graph"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.nodes[0].id").value("1"))
                    .andExpect(jsonPath("$.data.nodes[0].label").value("프로세스"))
                    .andExpect(jsonPath("$.data.nodes[0].description[0]").value("실행 중인 프로그램의 인스턴스입니다."))
                    .andExpect(jsonPath("$.data.nodes[0].learnedAt").value("2026-07-08"))
                    .andExpect(jsonPath("$.data.nodes[0].relatedSteps[0].stepOrder")
                            .value(1))
                    .andExpect(jsonPath("$.data.nodes[0].relatedSteps[0].topic").value("프로세스와 스레드"))
                    .andExpect(jsonPath("$.data.edges[0].source").value("1"))
                    .andExpect(jsonPath("$.data.edges[0].target").value("2"))
                    .andExpect(jsonPath("$.meta").doesNotExist());
        }

        @Test
        @DisplayName("학습한 개념이 없으면 에러가 아니라 빈 nodes/edges로 응답한다")
        void returns_empty_arrays_when_nothing_learned() throws Exception {
            authenticateAs(7L);
            given(historyService.getGraph(eq(7L))).willReturn(new HistoryGraphResponse(List.of(), List.of()));

            mockMvc.perform(get("/api/v1/history/graph"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.nodes.length()").value(0))
                    .andExpect(jsonPath("$.data.edges.length()").value(0));
        }
    }
}
