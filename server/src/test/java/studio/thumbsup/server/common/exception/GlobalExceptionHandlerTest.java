package studio.thumbsup.server.common.exception;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import jakarta.validation.Valid;
import jakarta.validation.Validation;
import jakarta.validation.ValidatorFactory;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.common.response.ApiResponse;

/**
 * 전역 예외 → envelope 변환 검증 — Spring 컨텍스트 없이 standalone MockMvc로 빠르게 돈다.
 */
class GlobalExceptionHandlerTest {

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.standaloneSetup(new StubController())
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Test
    void 비즈니스_예외는_ErrorType의_status와_code로_변환된다() throws Exception {
        mockMvc.perform(get("/stub/business"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_FOUND"))
                .andExpect(jsonPath("$.message").value("리소스를 찾을 수 없습니다."))
                .andExpect(jsonPath("$.data").value(nullValue()));
    }

    @Test
    void 검증_실패는_INVALID_INPUT과_fieldErrors로_변환된다() throws Exception {
        mockMvc.perform(post("/stub/validate")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\",\"email\":\"not-an-email\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_INPUT"))
                .andExpect(jsonPath("$.data.fieldErrors", hasSize(2)))
                .andExpect(jsonPath("$.data.fieldErrors[*].field", containsInAnyOrder("name", "email")));
    }

    @Test
    void 파라미터_검증_실패도_fieldErrors로_변환된다() {
        try (ValidatorFactory factory = Validation.buildDefaultValidatorFactory()) {
            Set<ConstraintViolation<StubRequest>> violations =
                    factory.getValidator().validateValue(StubRequest.class, "name", "");

            ResponseEntity<ApiResponse<ValidationErrorData>> response = new GlobalExceptionHandler()
                    .handleConstraintViolation(new ConstraintViolationException(violations));

            assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
            assertThat(response.getBody()).isNotNull();
            assertThat(response.getBody().code()).isEqualTo("INVALID_INPUT");
            assertThat(response.getBody().data().fieldErrors())
                    .extracting(FieldErrorDetail::field)
                    .containsExactly("name");
        }
    }

    @Test
    void 예상치_못한_예외는_INTERNAL_ERROR_고정_문구로_변환된다() throws Exception {
        mockMvc.perform(get("/stub/boom"))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.code").value("INTERNAL_ERROR"))
                .andExpect(jsonPath("$.message").value("서버 오류가 발생했습니다."));
    }

    @Test
    void 지원하지_않는_메서드는_METHOD_NOT_ALLOWED로_변환된다() throws Exception {
        mockMvc.perform(post("/stub/business"))
                .andExpect(status().isMethodNotAllowed())
                .andExpect(jsonPath("$.code").value("METHOD_NOT_ALLOWED"));
    }

    @Test
    void 지원하지_않는_ContentType은_UNSUPPORTED_MEDIA_TYPE으로_변환된다() throws Exception {
        mockMvc.perform(post("/stub/validate").contentType(MediaType.TEXT_PLAIN).content("plain"))
                .andExpect(status().isUnsupportedMediaType())
                .andExpect(jsonPath("$.code").value("UNSUPPORTED_MEDIA_TYPE"));
    }

    @RestController
    static class StubController {

        @GetMapping("/stub/business")
        public ApiResponse<Void> business() {
            throw new BusinessException(CommonErrorType.NOT_FOUND);
        }

        @PostMapping("/stub/validate")
        public ApiResponse<Void> validate(@Valid @RequestBody StubRequest request) {
            return ApiResponse.success();
        }

        @GetMapping("/stub/boom")
        public ApiResponse<Void> boom() {
            // 테스트 전용 — fallback 핸들러 검증 목적 (프로덕션 코드에선 표준 예외 생성 금지, ArchUnit 강제)
            throw new RuntimeException("boom");
        }
    }

    record StubRequest(@NotBlank String name, @Email String email) {}
}
