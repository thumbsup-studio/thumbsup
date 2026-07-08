package studio.thumbsup.server.common.config;

import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/** Swagger/OpenAPI 문서 접근용 Basic Auth 계정. 값은 local/prod SSM에서 주입한다. */
@ConfigurationProperties(prefix = "thumbsup.swagger.basic-auth")
@Validated
public record SwaggerBasicAuthProperties(
        @NotBlank String username, @NotBlank String password) {}
