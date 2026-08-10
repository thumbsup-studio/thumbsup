# 테스트 코드 작성 가이드

AI agent로 feature를 빠르게 만들수록 회귀 방어가 중요하다.
테스트는 적은 수의 고신뢰 테스트와 빠른 단위 테스트를 조합한다.

## 1. 실행 명령

```bash
cd server
./gradlew test
./gradlew build
./gradlew --no-daemon spotlessApply build
```

Repository/Context 테스트는 Testcontainers로 MySQL을 띄운다. Docker Desktop이 켜져 있어야 한다.
Gradle 테스트는 `test` profile을 사용하며 AWS SSM을 읽지 않는다.

## 2. 테스트 층

| 층 | 목적 | 도구 | 기준 |
|----|------|------|------|
| Service 단위 테스트 | 비즈니스 분기, 예외, 트랜잭션 밖 계산 | JUnit + Mockito | 빠르고 많이 작성 |
| Controller 계약 테스트 | 요청 검증, envelope, status, error code | standalone MockMvc | Spring 전체 부팅 없이 API 계약 검증 |
| Repository 통합 테스트 | Flyway 스키마, JPA 쿼리, DB 제약 | `@DataJpaTest` + Testcontainers MySQL | DB와 SQL 리스크 검증 |
| 보안/인수 테스트 | 필터체인, 인증, 주요 사용자 흐름 | `@SpringBootTest` + MockMvc + Testcontainers | 적게 작성하되 회귀 가치가 높은 경로만 |

새 API는 notice feature의 테스트 구조를 복제한다.

## 3. 인수 테스트 기준

모든 케이스를 full-stack으로 만들지 않는다. 다음 조건이면 인수 테스트를 추가한다.

- 인증/인가, CORS, Swagger Basic Auth처럼 필터체인에서 막히는 동작
- 여러 계층이 합쳐져야 깨지는 사용자 핵심 흐름
- Flyway 스키마와 JPA 매핑이 실제 MySQL에서 맞아야 하는 흐름
- 한번 깨지면 FE 계약이나 운영 배포에 바로 영향을 주는 흐름

단순 분기와 계산은 Service 단위 테스트로 끝낸다.

## 4. 테스트 이름

테스트는 `@Nested`와 `@DisplayName`으로 사람이 읽는 문장처럼 나눈다.

```java
@Nested
@DisplayName("공지 목록 조회")
class GetNotices {

    @Test
    @DisplayName("size가 최대치를 넘으면 INVALID_INPUT으로 응답한다")
    void rejects_too_large_size() {
        // given / when / then
    }
}
```

한글 DisplayName을 권장한다. 메서드명은 IDE 탐색과 리포트 안정성을 위해 ASCII snake_case를 쓴다.

## 5. Testcontainers 규칙

- H2를 쓰지 않는다. MySQL 8.4 Testcontainer를 사용한다.
- **컨테이너는 테스트 클래스마다 새로 띄우지 않는다.** `TestcontainersConfiguration`이 JVM(1회 `./gradlew test` 실행)당 MySQL 컨테이너 1개만 기동해 전체 테스트가 공유한다 — 클래스마다 Docker 컨테이너를 새로 띄우는 비용을 없애 전체 스위트 속도를 크게 줄인다.
- 새 통합 테스트는 컨테이너/어노테이션을 직접 선언하지 않고 아래 공통 베이스를 상속한다(`studio.thumbsup.server.common` 패키지). 패턴이 애매하면 프로즈보다 아래 예시 파일을 그대로 복제한다.
  - `@DataJpaTest` 슬라이스 테스트 → `RepositoryTestSupport` 상속 (예: `NoticeRepositoryTest`)
  - `@SpringBootTest` 인수/보안 테스트 → `AcceptanceTestSupport` 상속 (예: `NoticeAcceptanceTest`)
  - Spring 컨텍스트 없이 Flyway/JDBC로 마이그레이션을 직접 재생하는 테스트 → `MigrationTestSupport` 상속(공유 컨테이너는 `protected static final MySQLContainer<?> MYSQL`로 접근, 예: `QuizHintMigrationTest`)
- 컨테이너를 공유하는 대신 **클래스 단위 격리는 스키마 리셋으로 보장한다** — `RepositoryTestSupport`/`AcceptanceTestSupport`는 `@BeforeAll`에서 `TestcontainersConfiguration.resetSchema()`(Flyway `clean()`+`migrate()`)를 호출해 매 클래스를 "컨테이너를 새로 띄운 것"과 동일하게 깨끗한 시드 상태에서 시작시킨다. 클래스 안에서 `DatabaseCleanUp`으로 특정 테이블만 비우는 기존 관례(`@BeforeEach`)는 그대로 유지한다 — 서로 다른 층위의 격리라 중복이 아니다.
- 따라서 테스트가 스스로 `MySQLContainer`를 `@Container`로 선언하거나 `@ServiceConnection`을 붙이지 않는다 — `TestcontainersConfiguration`이 시스템 프로퍼티로 datasource를 직접 심는다.
- Flyway 마이그레이션이 실제로 적용되는지 Repository/Context 테스트에서 확인한다.
- Docker가 꺼져 실패한 테스트는 코드 성공으로 간주하지 않는다. Docker를 켜고 다시 돌린다.

## 6. PR 전 테스트 체크리스트

- 새 feature에 Service/Controller/Repository 테스트가 있는가
- 인증이 필요한 API면 미인증/권한 없음 케이스가 있는가
- 실패 케이스가 표준 error code를 검증하는가
- 날짜/시간은 고정 `Clock` 또는 명시적 fixture로 검증하는가
- `./gradlew --no-daemon spotlessApply build`가 통과했는가
