package studio.thumbsup.server.quiz.generation;

import jakarta.validation.constraints.NotBlank;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * 엘리스AX ML API(문제 생성용) 설정 — application.yml의 {@code thumbsup.elice.quiz.*}.
 *
 * <p>local=application-local.yml(SSM {@code /thumbsup/local/}), prod=SSM {@code /thumbsup/prod/}에서
 * 주입되며 default 값을 두지 않는다(fail-fast — server/docs/env-guide.md).
 * base-url·model은 용도별로 다르다는 팀 규약(스킬 elice-models)에 따라 이 프로퍼티는 "quiz 생성" 용도 전용이다.
 */
@ConfigurationProperties(prefix = "thumbsup.elice.quiz")
@Validated
public record EliceProperties(
        @NotBlank String apiKey,
        @NotBlank String baseUrl,
        @NotBlank String model) {}
