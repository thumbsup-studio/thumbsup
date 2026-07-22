package studio.thumbsup.server.notice;

import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.aop.framework.ProxyFactory;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.validation.beanvalidation.MethodValidationInterceptor;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.exception.GlobalExceptionHandler;
import studio.thumbsup.server.common.response.CursorMeta;
import studio.thumbsup.server.common.response.CursorPage;
import studio.thumbsup.server.notice.dto.NoticeDetailResponse;
import studio.thumbsup.server.notice.dto.NoticeListResponse;
import studio.thumbsup.server.notice.dto.NoticeListResponse.NoticeItem;

/** Controller 슬라이스 테스트 — standalone MockMvc로 요청/응답 계약만 검증한다 (피라미드 2층). */
@ExtendWith(MockitoExtension.class)
@DisplayName("공지 컨트롤러")
class NoticeControllerTest {

    @Mock
    private NoticeService noticeService;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        // standalone은 Boot 자동설정이 없으므로 운영과 동일하게 두 가지를 명시한다:
        // (1) 날짜를 ISO-8601로 직렬화하는 ObjectMapper
        //     ⚠️ 운영과 별개 인스턴스다 — application.yml에 spring.jackson 설정을 추가하면
        //        이 ObjectMapper도 동기화해야 테스트가 실제 직렬화를 검증한다
        ObjectMapper objectMapper = new ObjectMapper()
                .registerModule(new JavaTimeModule())
                .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

        // (2) @Validated 파라미터 검증(@Min/@Max) — 운영에선 AOP가 하는 일을 프록시로 재현
        ProxyFactory proxyFactory = new ProxyFactory(new NoticeController(noticeService));
        proxyFactory.addAdvice(new MethodValidationInterceptor());
        Object controller = proxyFactory.getProxy();

        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new GlobalExceptionHandler())
                .setMessageConverters(new MappingJackson2HttpMessageConverter(objectMapper))
                .build();
    }

    @Nested
    @DisplayName("목록 조회")
    class GetNotices {

        @Test
        @DisplayName("목록 응답은 공통 envelope와 커서 meta를 따른다")
        void returns_common_envelope_with_cursor_meta() throws Exception {
            NoticeItem item =
                    new NoticeItem(3L, "공지", OffsetDateTime.of(2026, 7, 7, 9, 0, 0, 0, ZoneOffset.ofHours(9)));
            // 서비스는 mock이므로 커서는 불투명 문자열 그대로 pass-through됨을 검증한다
            given(noticeService.getNotices(isNull(), anyInt()))
                    .willReturn(
                            new CursorPage<>(new NoticeListResponse(List.of(item)), CursorMeta.of(true, "cursor-3")));

            mockMvc.perform(get("/api/v1/notices"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.items[0].noticeId").value(3))
                    .andExpect(jsonPath("$.data.items[0].createdAt").value("2026-07-07T09:00:00+09:00"))
                    .andExpect(jsonPath("$.meta.hasNext").value(true))
                    .andExpect(jsonPath("$.meta.nextCursor").value("cursor-3"));
        }

        @Test
        @DisplayName("size가 최대치를 넘으면 INVALID_INPUT")
        void rejects_too_large_size_with_invalid_input() throws Exception {
            mockMvc.perform(get("/api/v1/notices").param("size", "200"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("INVALID_INPUT"));
        }
    }

    @Nested
    @DisplayName("상세 조회")
    class GetNotice {

        @Test
        @DisplayName("상세 응답은 content를 포함한 envelope를 따른다")
        void returns_detail_envelope_with_content() throws Exception {
            given(noticeService.getNotice(3L))
                    .willReturn(new NoticeDetailResponse(
                            3L, "공지", "본문 내용", OffsetDateTime.of(2026, 7, 7, 9, 0, 0, 0, ZoneOffset.ofHours(9))));

            mockMvc.perform(get("/api/v1/notices/3"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code").value("SUCCESS"))
                    .andExpect(jsonPath("$.data.noticeId").value(3))
                    .andExpect(jsonPath("$.data.content").value("본문 내용"))
                    .andExpect(jsonPath("$.meta").doesNotExist());
        }

        @Test
        @DisplayName("없는 공지는 NOTICE_NOT_FOUND 코드로 응답한다")
        void returns_notice_not_found_code() throws Exception {
            given(noticeService.getNotice(99L)).willThrow(new BusinessException(NoticeErrorType.NOTICE_NOT_FOUND));

            mockMvc.perform(get("/api/v1/notices/99"))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.code").value("NOTICE_NOT_FOUND"));
        }
    }
}
