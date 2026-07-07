package studio.thumbsup.server.common.config;

import java.time.Clock;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 시간은 항상 이 Clock 빈을 주입받아 사용한다 — {@code LocalDateTime.now()} 직접 호출 금지.
 * 테스트에서 {@code Clock.fixed(...)}로 바꿔치기해 시간 의존 로직을 결정적으로 검증한다.
 */
@Configuration
public class ClockConfig {

    @Bean
    public Clock clock() {
        return Clock.systemUTC(); // 저장은 UTC — 계약: docs/api-standard.md §5
    }
}
