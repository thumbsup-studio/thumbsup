package studio.thumbsup.server.notice;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.BeforeEach;
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

/**
 * 공지 조회 API 인수 테스트 — 저장된 공지가 JPA·DTO·인증 필터체인을 거쳐 공통 envelope로 노출되는지 검증한다 (피라미드 4층).
 *
 * <p>docs/testing-guide.md §3 기준으로 인수 층에 두는 이유: 인증 필터체인 통과 + 실제 MySQL의 커서
 * 페이지네이션 + 공통 응답 계약이 함께 맞아야 하는 흐름이기 때문이다. 페이지네이션 경계·커서 디코딩 같은
 * 분기는 {@code NoticeServiceTest}가, 요청 검증·envelope 형태는 {@code NoticeControllerTest}가 담당하므로
 * 여기서 반복하지 않는다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@ActiveProfiles("test")
class NoticeAcceptanceTest {

    /** 공지 API는 유저 식별을 쓰지 않지만, 인증 필터체인을 통과하려면 유효한 토큰이 필요하다. */
    private static final long TEST_USER_ID = 1L;

    private static final long ABSENT_NOTICE_ID = 999_999L;

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final MockMvc mockMvc;
    private final ObjectMapper objectMapper;
    private final JwtTokenProvider jwtTokenProvider;
    private final NoticeRepository noticeRepository;

    NoticeAcceptanceTest(
            @Autowired MockMvc mockMvc,
            @Autowired ObjectMapper objectMapper,
            @Autowired JwtTokenProvider jwtTokenProvider,
            @Autowired NoticeRepository noticeRepository) {
        this.mockMvc = mockMvc;
        this.objectMapper = objectMapper;
        this.jwtTokenProvider = jwtTokenProvider;
        this.noticeRepository = noticeRepository;
    }

    private Long oldestId;
    private Long newestId;

    @BeforeEach
    void seedNotices() {
        // 이 클래스는 @Transactional이 없어 저장 행이 남으므로 매 테스트마다 초기화한다 (시드가 없는 테이블).
        noticeRepository.deleteAll();
        // 저장 순서 = id 오름차순 → 마지막에 저장한 "셋째"가 id 내림차순 목록의 맨 앞에 온다.
        oldestId = noticeRepository.save(Notice.create("첫째 공지", "첫째 본문")).getId();
        noticeRepository.save(Notice.create("둘째 공지", "둘째 본문"));
        newestId = noticeRepository.save(Notice.create("셋째 공지", "셋째 본문")).getId();
    }

    private String bearerToken() {
        return "Bearer " + jwtTokenProvider.createAccessToken(TEST_USER_ID);
    }

    @Nested
    @DisplayName("GET /api/v1/notices")
    class GetNotices {

        @Test
        @DisplayName("공통 envelope와 커서 meta로 최신순(id 내림차순) 목록을 반환한다")
        void returns_notices_in_id_desc_with_cursor_meta() throws Exception {
            mockMvc.perform(get("/api/v1/notices").param("size", "2").header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.items.length()").value(2))
                    .andExpect(jsonPath("$.data.items[0].noticeId").value(newestId))
                    .andExpect(jsonPath("$.data.items[0].title").value("셋째 공지"))
                    .andExpect(jsonPath("$.meta.hasNext").value(true))
                    .andExpect(jsonPath("$.meta.nextCursor").isNotEmpty());
        }

        @Test
        @DisplayName("nextCursor로 이어서 조회하면 남은 항목이 내려오고 hasNext는 false다")
        void follows_cursor_to_next_page() throws Exception {
            String firstPage = mockMvc.perform(
                            get("/api/v1/notices").param("size", "2").header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isOk())
                    .andReturn()
                    .getResponse()
                    .getContentAsString(StandardCharsets.UTF_8);
            String nextCursor = objectMapper
                    .readTree(firstPage)
                    .path("meta")
                    .path("nextCursor")
                    .asText();

            mockMvc.perform(get("/api/v1/notices")
                            .param("size", "2")
                            .param("cursor", nextCursor)
                            .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.items.length()").value(1))
                    .andExpect(jsonPath("$.data.items[0].noticeId").value(oldestId))
                    .andExpect(jsonPath("$.meta.hasNext").value(false));
        }

        @Test
        @DisplayName("size가 최대치를 넘으면 INVALID_INPUT으로 막는다")
        void rejects_too_large_size() throws Exception {
            mockMvc.perform(get("/api/v1/notices")
                            .param("size", "200")
                            .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("INVALID_INPUT"));
        }

        @Test
        @DisplayName("Authorization 헤더가 없으면 필터체인이 401로 막는다")
        void returns_401_without_token() throws Exception {
            mockMvc.perform(get("/api/v1/notices")).andExpect(status().isUnauthorized());
        }
    }

    @Nested
    @DisplayName("GET /api/v1/notices/{noticeId}")
    class GetNotice {

        @Test
        @DisplayName("목록에 없는 content까지 포함한 상세를 envelope로 반환한다")
        void returns_detail_with_content() throws Exception {
            mockMvc.perform(get("/api/v1/notices/{noticeId}", newestId)
                            .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.noticeId").value(newestId))
                    .andExpect(jsonPath("$.data.content").value("셋째 본문"))
                    .andExpect(jsonPath("$.meta").doesNotExist());
        }

        @Test
        @DisplayName("존재하지 않는 공지면 404 NOTICE_NOT_FOUND를 반환한다")
        void returns_404_when_absent() throws Exception {
            mockMvc.perform(get("/api/v1/notices/{noticeId}", ABSENT_NOTICE_ID)
                            .header(HttpHeaders.AUTHORIZATION, bearerToken()))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.code").value("NOTICE_NOT_FOUND"));
        }
    }
}
