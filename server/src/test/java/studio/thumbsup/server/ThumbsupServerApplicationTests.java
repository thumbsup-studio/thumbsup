package studio.thumbsup.server;

import org.junit.jupiter.api.Test;
import studio.thumbsup.server.common.support.AcceptanceTestSupport;

/**
 * 컨텍스트 로딩 스모크 테스트 — 실제 MySQL(Testcontainers)로 검증한다.
 * H2 등 인메모리 DB는 쓰지 않는다 ("내 로컬에선 됐는데" 방지).
 */
class ThumbsupServerApplicationTests extends AcceptanceTestSupport {

    @Test
    void contextLoads() {}
}
