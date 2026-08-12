package studio.thumbsup.server.common.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.httpBasic;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.test.web.servlet.MockMvc;
import studio.thumbsup.server.common.support.AcceptanceTestSupport;

class SwaggerSecurityTest extends AcceptanceTestSupport {

    static Stream<String> swaggerDocumentPaths() {
        return Stream.of(
                "/swagger-ui.html",
                "/swagger-ui/index.html",
                "/v3/api-docs",
                "/v3/api-docs.yaml",
                "/v3/api-docs/swagger-config");
    }

    private final MockMvc mockMvc;

    SwaggerSecurityTest(@Autowired MockMvc mockMvc) {
        this.mockMvc = mockMvc;
    }

    @Nested
    @DisplayName("Swagger Basic Auth")
    class SwaggerBasicAuth {

        @Test
        @DisplayName("인증 없이 OpenAPI 문서에 접근하면 Basic 인증을 요구한다")
        void openapi_requires_basic_auth() throws Exception {
            mockMvc.perform(get("/v3/api-docs"))
                    .andExpect(status().isUnauthorized())
                    .andExpect(header().string(HttpHeaders.WWW_AUTHENTICATE, containsString("Basic")));
        }

        @ParameterizedTest
        @MethodSource("studio.thumbsup.server.common.config.SwaggerSecurityTest#swaggerDocumentPaths")
        @DisplayName("Swagger/OpenAPI 경로는 인증 없이 접근하면 Basic 인증을 요구한다")
        void swagger_paths_require_basic_auth(String path) throws Exception {
            mockMvc.perform(get(path))
                    .andExpect(status().isUnauthorized())
                    .andExpect(header().string(HttpHeaders.WWW_AUTHENTICATE, containsString("Basic")));
        }

        @ParameterizedTest
        @MethodSource("studio.thumbsup.server.common.config.SwaggerSecurityTest#swaggerDocumentPaths")
        @DisplayName("잘못된 Swagger 계정이면 Swagger/OpenAPI 경로 접근을 거부한다")
        void swagger_paths_reject_wrong_basic_auth(String path) throws Exception {
            mockMvc.perform(get(path).with(httpBasic("swagger-test", "wrong-password")))
                    .andExpect(status().isUnauthorized());
        }

        @Test
        @DisplayName("잘못된 Swagger username이면 비밀번호가 맞아도 접근을 거부한다")
        void swagger_rejects_wrong_username() throws Exception {
            mockMvc.perform(get("/v3/api-docs").with(httpBasic("wrong-user", "swagger-test-password")))
                    .andExpect(status().isUnauthorized());
        }

        @ParameterizedTest
        @MethodSource("studio.thumbsup.server.common.config.SwaggerSecurityTest#swaggerDocumentPaths")
        @DisplayName("올바른 Swagger 계정이면 Swagger/OpenAPI 경로 접근을 통과시킨다")
        void swagger_paths_allow_valid_basic_auth(String path) throws Exception {
            mockMvc.perform(get(path).with(httpBasic("swagger-test", "swagger-test-password")))
                    .andExpect(result ->
                            assertThat(result.getResponse().getStatus()).isNotIn(401, 403));
        }

        @Test
        @DisplayName("올바른 Swagger 계정이면 OpenAPI 문서를 조회할 수 있다")
        void openapi_allows_valid_basic_auth() throws Exception {
            mockMvc.perform(get("/v3/api-docs").with(httpBasic("swagger-test", "swagger-test-password")))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.openapi").exists());
        }
    }
}
