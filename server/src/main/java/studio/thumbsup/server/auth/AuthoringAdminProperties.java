package studio.thumbsup.server.auth;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 저작 관리자 사전 지정 이메일 목록(#174 C1) — {@link AuthService}가 토큰 발급 시점마다 이 목록과
 * 유저 이메일을 대조해 자동으로 ADMIN 승격한다(self-heal). 시크릿이 아니라 default 없음(fail-fast)
 * 대상도 아니다 — 비어 있으면 자동 승격이 그냥 없을 뿐이다. prod는 SSM
 * {@code ${AUTHORING_ADMIN_EMAILS}}(콤마 구분, /thumbsup/prod/AUTHORING_ADMIN_EMAILS)로 주입한다.
 */
@ConfigurationProperties(prefix = "thumbsup.authoring")
public record AuthoringAdminProperties(List<String> adminEmails) {

    public AuthoringAdminProperties {
        adminEmails = adminEmails == null ? List.of() : List.copyOf(adminEmails);
    }
}
