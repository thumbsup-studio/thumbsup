package studio.thumbsup.server;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * 컨텍스트 로딩 스모크 테스트 — 실제 MySQL(Testcontainers)로 검증한다.
 * H2 등 인메모리 DB는 쓰지 않는다 ("내 로컬에선 됐는데" 방지).
 */
@SpringBootTest
@Testcontainers
class ThumbsupServerApplicationTests {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    @Test
    void contextLoads() {}
}
