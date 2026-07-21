# 로그인 인증 API (#44) Implementation Plan

> **For agentic workers:** Implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 이메일/비밀번호 기반 회원가입·로그인·토큰 재발급(회전)·로그아웃 API를 구현한다 (소셜 로그인 제외 — M3).

**Architecture:** `studio.thumbsup.server.auth` 단일 feature 패키지에 `User`/`RefreshToken` 엔티티와 `AuthController`→`AuthService`→`{User,RefreshToken}Repository` 계층을 `notice/` 레퍼런스 패턴 그대로 구현한다. Access token은 기존 `JwtTokenProvider`(변경 없음)를 재사용하고, refresh token은 `SecureRandom` 기반 불투명 문자열을 SHA-256 해시로만 DB에 저장한다.

**Tech Stack:** Spring Boot 3(Web/Data JPA/Security/Validation), jjwt(access token — 기존 코드 재사용), Flyway(MySQL), JUnit5 + Mockito + AssertJ + Testcontainers.

**설계 근거 전체:** `docs/specs/2026-07-07-auth-login-api-design.md` (결정 기록 표 포함, 미커밋 상태 — 이 플랜과 함께 리뷰)

## Global Constraints

- API 베이스 경로 `/api/v1`, 모든 응답은 `ApiResponse{code,message,data,meta}` envelope (`docs/api-standard.md` §2)
- 생성 성공 = HTTP 201, 그 외 성공 = 200, 204 사용 안 함 (`docs/api-standard.md` §3)
- 인증: `Authorization: Bearer {accessToken}`. Access token 수명 30분, refresh token 수명 14일 + DB 저장 + 회전(rotation) (`docs/api-standard.md` §8)
- 유저 식별은 항상 토큰에서 — request body/param의 식별값 신뢰 금지 (IDOR 방지, `docs/api-standard.md` §8)
- 표준 예외(`IllegalArgumentException` 등) 직접 생성 금지 — 항상 `BusinessException(ErrorType)` (ArchUnit이 CI에서 강제)
- 생성자 주입만 (필드 `@Autowired` 금지), `@Transactional`은 `@Service` 클래스에만, Controller는 Repository/Entity 직접 사용 금지 (ArchUnit 강제)
- feature 패키지 간 직접 의존 금지 (`common` 제외, ArchUnit 강제) — 이번 작업은 `auth` 패키지 하나로 완결
- JPA 엔티티를 API 응답으로 직접 반환 금지 — API별 `record` DTO + 정적 팩토리 `from()`/`of()`, DTO 재사용 금지
- 시간은 주입받은 `Clock` 사용 (`Instant.now()`/`LocalDateTime.now()` 직접 호출 금지)
- 한 PR = 마이그레이션 파일 1개, 적용된 마이그레이션은 수정 금지 (수정은 새 파일로)
- 비밀번호 최소 8자(문자 종류 제한 없음), 로그인 실패는 원인 구분 없이 `INVALID_CREDENTIALS` 단일 코드
- 테스트 4종(Service/Controller/Repository/Fixture) 없는 PR 금지, `./gradlew build`(테스트+ArchUnit+Spotless+Checkstyle) 통과 후 PR

---

### Task 1: Flyway 마이그레이션 + User 엔티티/리포지토리

**Files:**
- Create: `server/src/main/resources/db/migration/V<timestamp>__create_auth_tables.sql`
- Create: `server/src/main/java/studio/thumbsup/server/auth/User.java`
- Create: `server/src/main/java/studio/thumbsup/server/auth/UserRepository.java`
- Test: `server/src/test/java/studio/thumbsup/server/auth/AuthFixture.java`
- Test: `server/src/test/java/studio/thumbsup/server/auth/UserRepositoryTest.java`

**Interfaces:**
- Produces: `User` (`Getter`: `getId()`, `getEmail()`, `getPassword()`, `getCreatedAt()`, `getUpdatedAt()`), 정적 팩토리 `User.create(String email, String password)`
- Produces: `UserRepository extends JpaRepository<User, Long>` — `Optional<User> findByEmail(String)`, `boolean existsByEmail(String)`
- Produces: `AuthFixture.user(Long id, String email, String password)` — 이후 태스크에서 계속 사용

- [ ] **Step 1: 마이그레이션 타임스탬프 생성**

Run: `date +%Y%m%d%H%M%S`
Expected: 14자리 숫자 (예: `20260708090000`) — 이후 `<timestamp>`로 사용. `V20260707213712__create_notice.sql`보다 큰 값이어야 한다.

- [ ] **Step 2: 마이그레이션 파일 작성**

`server/src/main/resources/db/migration/V<timestamp>__create_auth_tables.sql`:

```sql
-- 로그인 인증(#44) — users, refresh_token
-- 규칙: 버전 = 타임스탬프(yyyyMMddHHmmss), PR당 마이그레이션 1개, 적용된 파일 수정 금지(수정은 새 파일로)
-- 테이블명은 users(복수) — user는 MySQL 예약어라 매 쿼리 백틱이 필요해 실용적으로 예외 처리
CREATE TABLE users (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    email         VARCHAR(255) NOT NULL,
    password      VARCHAR(255) NOT NULL,
    created_at    DATETIME(6)  NOT NULL,
    updated_at    DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_users_email (email)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

CREATE TABLE refresh_token (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    user_id    BIGINT       NOT NULL,
    token_hash VARCHAR(64)  NOT NULL,
    expires_at DATETIME(6)  NOT NULL,
    created_at DATETIME(6)  NOT NULL,
    updated_at DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_refresh_token_hash (token_hash),
    CONSTRAINT fk_refresh_token_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;
```

- [ ] **Step 3: User 엔티티 작성**

`server/src/main/java/studio/thumbsup/server/auth/User.java`:

```java
package studio.thumbsup.server.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/**
 * 유저 엔티티 — 자체 로그인(이메일/비밀번호)만 다룬다.
 * 닉네임 등 프로필 필드는 온보딩 이슈 스코프. 생성은 정적 팩토리 {@link #create}로만.
 */
@Getter
@Entity
@Table(name = "users")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class User extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 255)
    private String email;

    @Column(nullable = false, length = 255)
    private String password;

    private User(String email, String password) {
        this.email = email;
        this.password = password;
    }

    public static User create(String email, String password) {
        return new User(email, password);
    }
}
```

- [ ] **Step 4: UserRepository 작성**

`server/src/main/java/studio/thumbsup/server/auth/UserRepository.java`:

```java
package studio.thumbsup.server.auth;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<User, Long> {

    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);
}
```

- [ ] **Step 5: AuthFixture 작성 (실패하는 테스트보다 먼저 — 이후 모든 테스트가 의존)**

`server/src/test/java/studio/thumbsup/server/auth/AuthFixture.java`:

```java
package studio.thumbsup.server.auth;

import java.time.Instant;
import org.springframework.test.util.ReflectionTestUtils;

/** auth 테스트 픽스처 — feature 소유. 영속화 없이 id·감사 필드를 채워 단위테스트에서 사용한다. */
public final class AuthFixture {

    public static final Instant CREATED_AT = Instant.parse("2026-07-07T00:00:00Z");

    public static User user(Long id, String email, String password) {
        User user = User.create(email, password);
        ReflectionTestUtils.setField(user, "id", id);
        ReflectionTestUtils.setField(user, "createdAt", CREATED_AT);
        ReflectionTestUtils.setField(user, "updatedAt", CREATED_AT);
        return user;
    }

    public static RefreshToken refreshToken(Long id, Long userId, String tokenHash, Instant expiresAt) {
        RefreshToken token = RefreshToken.create(userId, tokenHash, expiresAt);
        ReflectionTestUtils.setField(token, "id", id);
        ReflectionTestUtils.setField(token, "createdAt", CREATED_AT);
        ReflectionTestUtils.setField(token, "updatedAt", CREATED_AT);
        return token;
    }

    private AuthFixture() {}
}
```

이 파일은 Task 2에서 만들 `RefreshToken`을 참조하므로 지금은 컴파일되지 않는다 — Task 2 완료 시점에 함께 컴파일된다(다음 Step에서 `UserRepositoryTest`만 먼저 검증).

- [ ] **Step 6: 실패하는 UserRepositoryTest 작성**

`server/src/test/java/studio/thumbsup/server/auth/UserRepositoryTest.java`:

```java
package studio.thumbsup.server.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Import;
import org.springframework.dao.DataIntegrityViolationException;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.config.ClockConfig;
import studio.thumbsup.server.common.config.JpaAuditingConfig;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@Import({ClockConfig.class, JpaAuditingConfig.class})
class UserRepositoryTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final UserRepository userRepository;

    UserRepositoryTest(@Autowired UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Test
    void 이메일로_유저를_조회한다() {
        userRepository.save(User.create("a@test.com", "hashed"));

        assertThat(userRepository.findByEmail("a@test.com")).isPresent();
        assertThat(userRepository.findByEmail("nobody@test.com")).isEmpty();
    }

    @Test
    void 이메일_존재_여부를_확인한다() {
        userRepository.save(User.create("dup@test.com", "hashed"));

        assertThat(userRepository.existsByEmail("dup@test.com")).isTrue();
        assertThat(userRepository.existsByEmail("nobody@test.com")).isFalse();
    }

    @Test
    void 이메일_중복_저장은_제약_위반으로_거부된다() {
        userRepository.saveAndFlush(User.create("dup@test.com", "hashed"));

        assertThrows(
                DataIntegrityViolationException.class,
                () -> userRepository.saveAndFlush(User.create("dup@test.com", "other-hash")));
    }
}
```

Run: `./gradlew test --tests "studio.thumbsup.server.auth.UserRepositoryTest"`
Expected: FAIL — `RefreshToken`/`RefreshTokenRepository` 클래스가 없어 컴파일 에러 (Task 2에서 해결)

- [ ] **Step 7: Task 2까지 이어서 진행** (컴파일 성공 확인은 Task 2의 Step 3에서)

---

### Task 2: RefreshToken 엔티티/리포지토리

**Files:**
- Create: `server/src/main/java/studio/thumbsup/server/auth/RefreshToken.java`
- Create: `server/src/main/java/studio/thumbsup/server/auth/RefreshTokenRepository.java`
- Test: `server/src/test/java/studio/thumbsup/server/auth/RefreshTokenRepositoryTest.java`

**Interfaces:**
- Consumes: 없음 (User와 값 참조만, JPA 연관관계 없음)
- Produces: `RefreshToken` — `getId()`, `getUserId()`, `getTokenHash()`, `getExpiresAt()`, 정적 팩토리 `RefreshToken.create(Long userId, String tokenHash, Instant expiresAt)`, `boolean isExpired(Clock clock)`
- Produces: `RefreshTokenRepository extends JpaRepository<RefreshToken, Long>` — `Optional<RefreshToken> findByTokenHash(String)`, `void deleteByUserId(Long)`

- [ ] **Step 1: RefreshToken 엔티티 작성**

`server/src/main/java/studio/thumbsup/server/auth/RefreshToken.java`:

```java
package studio.thumbsup.server.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Clock;
import java.time.Instant;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import studio.thumbsup.server.common.entity.BaseEntity;

/**
 * refresh token 엔티티 — 원문은 저장하지 않고 SHA-256 해시만 저장한다({@code tokenHash}).
 * 유저당 1개 유지(회전 시 기존 row 삭제 후 재생성) — {@link RefreshTokenRepository#deleteByUserId}.
 * {@code userId}는 JPA 연관관계가 아닌 값 참조 + DB FK 제약(마이그레이션에 정의).
 */
@Getter
@Entity
@Table(name = "refresh_token")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class RefreshToken extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "token_hash", nullable = false, unique = true, length = 64)
    private String tokenHash;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    private RefreshToken(Long userId, String tokenHash, Instant expiresAt) {
        this.userId = userId;
        this.tokenHash = tokenHash;
        this.expiresAt = expiresAt;
    }

    public static RefreshToken create(Long userId, String tokenHash, Instant expiresAt) {
        return new RefreshToken(userId, tokenHash, expiresAt);
    }

    public boolean isExpired(Clock clock) {
        return expiresAt.isBefore(clock.instant());
    }
}
```

- [ ] **Step 2: RefreshTokenRepository 작성**

`server/src/main/java/studio/thumbsup/server/auth/RefreshTokenRepository.java`:

```java
package studio.thumbsup.server.auth;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    Optional<RefreshToken> findByTokenHash(String tokenHash);

    void deleteByUserId(Long userId);
}
```

- [ ] **Step 3: Task 1의 UserRepositoryTest 통과 확인 (컴파일 해소됨)**

Run: `./gradlew test --tests "studio.thumbsup.server.auth.UserRepositoryTest"`
Expected: PASS (3 tests)

- [ ] **Step 4: RefreshTokenRepositoryTest 작성**

`server/src/test/java/studio/thumbsup/server/auth/RefreshTokenRepositoryTest.java`:

```java
package studio.thumbsup.server.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Import;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import studio.thumbsup.server.common.config.ClockConfig;
import studio.thumbsup.server.common.config.JpaAuditingConfig;

@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
@Import({ClockConfig.class, JpaAuditingConfig.class})
class RefreshTokenRepositoryTest {

    @Container
    @ServiceConnection
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4");

    private final RefreshTokenRepository refreshTokenRepository;

    RefreshTokenRepositoryTest(@Autowired RefreshTokenRepository refreshTokenRepository) {
        this.refreshTokenRepository = refreshTokenRepository;
    }

    @Test
    void 토큰_해시로_조회한다() {
        refreshTokenRepository.save(RefreshToken.create(1L, "hash-1", Instant.parse("2026-07-21T00:00:00Z")));

        assertThat(refreshTokenRepository.findByTokenHash("hash-1")).isPresent();
        assertThat(refreshTokenRepository.findByTokenHash("nope")).isEmpty();
    }

    @Test
    void 유저_id로_삭제하면_조회되지_않는다() {
        refreshTokenRepository.save(RefreshToken.create(7L, "hash-7", Instant.parse("2026-07-21T00:00:00Z")));

        refreshTokenRepository.deleteByUserId(7L);

        assertThat(refreshTokenRepository.findByTokenHash("hash-7")).isEmpty();
    }
}
```

- [ ] **Step 5: 테스트 실행**

Run: `./gradlew test --tests "studio.thumbsup.server.auth.RefreshTokenRepositoryTest"`
Expected: PASS (2 tests)

- [ ] **Step 6: 커밋**

```bash
git add server/src/main/resources/db/migration server/src/main/java/studio/thumbsup/server/auth server/src/test/java/studio/thumbsup/server/auth
git commit -m "feat(server): 로그인 인증 — User/RefreshToken 엔티티·리포지토리 (#44)"
```

---

### Task 3: JwtProperties에 refreshTokenValidity 추가

**Files:**
- Modify: `server/src/main/java/studio/thumbsup/server/common/security/JwtProperties.java`
- Modify: `server/src/main/resources/application.yml`
- Modify: `server/src/test/java/studio/thumbsup/server/common/security/JwtTokenProviderTest.java` (기존 생성자 호출부 시그니처 변경 대응)

**Interfaces:**
- Produces: `JwtProperties(String secret, Duration accessTokenValidity, Duration refreshTokenValidity)` — Task 6에서 `AuthService`가 `refreshTokenValidity()` 사용

- [ ] **Step 1: JwtProperties에 필드 추가**

`server/src/main/java/studio/thumbsup/server/common/security/JwtProperties.java` 전체를 다음으로 교체:

```java
package studio.thumbsup.server.common.security;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * JWT 설정 — application.yml의 {@code thumbsup.jwt.*}.
 *
 * <p>secret은 환경별 주입(local=application-local.yml, prod=SSM ${JWT_SECRET})이며
 * default 값을 두지 않는다 (fail-fast — server/docs/env-guide.md).
 */
@ConfigurationProperties(prefix = "thumbsup.jwt")
@Validated
public record JwtProperties(
        @NotBlank String secret, @NotNull Duration accessTokenValidity, @NotNull Duration refreshTokenValidity) {}
```

- [ ] **Step 2: application.yml에 refresh-token-validity 추가**

`server/src/main/resources/application.yml`의 `thumbsup.jwt` 블록을 수정:

```yaml
thumbsup:
  jwt:
    access-token-validity: 30m # 계약: docs/api-standard.md §8 (secret은 환경별 — 여기 두지 않는다)
    refresh-token-validity: 14d # 계약: docs/api-standard.md §8
```

- [ ] **Step 3: 기존 JwtTokenProviderTest 컴파일 오류 해소**

`server/src/test/java/studio/thumbsup/server/common/security/JwtTokenProviderTest.java`에서
`new JwtProperties(SECRET, VALIDITY)` 두 곳을 찾아 세 번째 인자를 추가한다.

파일 상단 필드에 추가:

```java
    private static final Duration REFRESH_VALIDITY = Duration.ofDays(14);
```

`providerAt` 메서드:

```java
    private JwtTokenProvider providerAt(Instant instant) {
        return new JwtTokenProvider(
                new JwtProperties(SECRET, VALIDITY, REFRESH_VALIDITY), Clock.fixed(instant, ZoneOffset.UTC));
    }
```

`서명이_다른_토큰은_JwtException을_던진다` 테스트 내부:

```java
        JwtTokenProvider otherKeyProvider = new JwtTokenProvider(
                new JwtProperties("another-secret-key-for-jwt-hmac-sha-256-32bytes!!", VALIDITY, REFRESH_VALIDITY),
                Clock.fixed(BASE_TIME, ZoneOffset.UTC));
```

- [ ] **Step 4: 테스트 실행 (기존 테스트가 여전히 통과하는지 확인)**

Run: `./gradlew test --tests "studio.thumbsup.server.common.security.JwtTokenProviderTest"`
Expected: PASS (4 tests)

- [ ] **Step 5: 전체 애플리케이션 컨텍스트 로딩 확인 (필수 설정값 fail-fast 검증)**

Run: `./gradlew test --tests "studio.thumbsup.server.ThumbsupServerApplicationTests"`
Expected: PASS — `thumbsup.jwt.refresh-token-validity` 미설정 시 `@NotNull` 위반으로 부팅 실패하므로, 이 테스트 통과가 곧 yml 설정이 올바름을 증명한다

- [ ] **Step 6: 커밋**

```bash
git add server/src/main/java/studio/thumbsup/server/common/security/JwtProperties.java server/src/main/resources/application.yml server/src/test/java/studio/thumbsup/server/common/security/JwtTokenProviderTest.java
git commit -m "feat(server): JwtProperties에 refresh token 유효기간 추가 (#44)"
```

---

### Task 4: AuthErrorType

**Files:**
- Create: `server/src/main/java/studio/thumbsup/server/auth/AuthErrorType.java`

**Interfaces:**
- Produces: `AuthErrorType implements ErrorType` — `USER_EMAIL_DUPLICATED`(409), `INVALID_CREDENTIALS`(401), `INVALID_REFRESH_TOKEN`(401). Task 6/7에서 `AuthService`가 `BusinessException`과 함께 사용.

- [ ] **Step 1: AuthErrorType 작성** (별도 테스트 없음 — enum이며 Service/Controller 테스트에서 간접 검증)

`server/src/main/java/studio/thumbsup/server/auth/AuthErrorType.java`:

```java
package studio.thumbsup.server.auth;

import org.springframework.http.HttpStatus;
import studio.thumbsup.server.common.exception.ErrorType;

/**
 * 인증 도메인 에러 — feature 소유 (common에 추가하지 않는다).
 * 코드 값 = enum 이름, 한 번 배포되면 변경 금지 (FE 분기가 깨진다).
 */
public enum AuthErrorType implements ErrorType {
    USER_EMAIL_DUPLICATED(HttpStatus.CONFLICT, "이미 가입된 이메일입니다."),
    INVALID_CREDENTIALS(HttpStatus.UNAUTHORIZED, "이메일 또는 비밀번호가 올바르지 않습니다."),
    INVALID_REFRESH_TOKEN(HttpStatus.UNAUTHORIZED, "유효하지 않은 토큰입니다.");

    private final HttpStatus status;
    private final String message;

    AuthErrorType(HttpStatus status, String message) {
        this.status = status;
        this.message = message;
    }

    @Override
    public HttpStatus getStatus() {
        return status;
    }

    @Override
    public String getCode() {
        return name();
    }

    @Override
    public String getMessage() {
        return message;
    }
}
```

- [ ] **Step 2: 컴파일 확인**

Run: `./gradlew compileJava`
Expected: BUILD SUCCESSFUL

- [ ] **Step 3: 커밋**

```bash
git add server/src/main/java/studio/thumbsup/server/auth/AuthErrorType.java
git commit -m "feat(server): AuthErrorType 추가 (#44)"
```

---

### Task 5: 요청/응답 DTO

**Files:**
- Create: `server/src/main/java/studio/thumbsup/server/auth/dto/SignupRequest.java`
- Create: `server/src/main/java/studio/thumbsup/server/auth/dto/LoginRequest.java`
- Create: `server/src/main/java/studio/thumbsup/server/auth/dto/RefreshRequest.java`
- Create: `server/src/main/java/studio/thumbsup/server/auth/dto/AuthTokenResponse.java`

**Interfaces:**
- Produces: `SignupRequest(String email, String password)`, `LoginRequest(String email, String password)`,
  `RefreshRequest(String refreshToken)`, `AuthTokenResponse(String accessToken, String refreshToken)` +
  정적 팩토리 `AuthTokenResponse.of(String, String)` — Task 6/7의 `AuthService`, Task 8의 `AuthController`가 사용

- [ ] **Step 1: SignupRequest 작성**

`server/src/main/java/studio/thumbsup/server/auth/dto/SignupRequest.java`:

```java
package studio.thumbsup.server.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** POST /api/v1/auth/signup 요청 DTO. */
public record SignupRequest(
        @NotBlank(message = "이메일은 필수입니다.") @Email(message = "이메일 형식이 아닙니다.") String email,
        @NotBlank(message = "비밀번호는 필수입니다.") @Size(min = 8, message = "8자 이상이어야 합니다.") String password) {}
```

- [ ] **Step 2: LoginRequest 작성**

`server/src/main/java/studio/thumbsup/server/auth/dto/LoginRequest.java`:

```java
package studio.thumbsup.server.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

/** POST /api/v1/auth/login 요청 DTO. */
public record LoginRequest(
        @NotBlank(message = "이메일은 필수입니다.") @Email(message = "이메일 형식이 아닙니다.") String email,
        @NotBlank(message = "비밀번호는 필수입니다.") String password) {}
```

- [ ] **Step 3: RefreshRequest 작성**

`server/src/main/java/studio/thumbsup/server/auth/dto/RefreshRequest.java`:

```java
package studio.thumbsup.server.auth.dto;

import jakarta.validation.constraints.NotBlank;

/** POST /api/v1/auth/refresh 요청 DTO. */
public record RefreshRequest(@NotBlank(message = "refreshToken은 필수입니다.") String refreshToken) {}
```

- [ ] **Step 4: AuthTokenResponse 작성**

`server/src/main/java/studio/thumbsup/server/auth/dto/AuthTokenResponse.java`:

```java
package studio.thumbsup.server.auth.dto;

/** signup/login/refresh 공통 응답 DTO — accessToken은 이후 요청의 Authorization 헤더로, refreshToken은 재발급에 사용. */
public record AuthTokenResponse(String accessToken, String refreshToken) {

    public static AuthTokenResponse of(String accessToken, String refreshToken) {
        return new AuthTokenResponse(accessToken, refreshToken);
    }
}
```

- [ ] **Step 5: 컴파일 확인**

Run: `./gradlew compileJava`
Expected: BUILD SUCCESSFUL

- [ ] **Step 6: 커밋**

```bash
git add server/src/main/java/studio/thumbsup/server/auth/dto
git commit -m "feat(server): 인증 API 요청/응답 DTO 추가 (#44)"
```

---

### Task 6: AuthService — signup/login

**Files:**
- Create: `server/src/main/java/studio/thumbsup/server/auth/AuthService.java`
- Test: `server/src/test/java/studio/thumbsup/server/auth/AuthServiceTest.java`

**Interfaces:**
- Consumes: `UserRepository`, `RefreshTokenRepository`(Task 1·2), `JwtProperties`, `JwtTokenProvider`(Task 3, 기존),
  `PasswordEncoder`(기존 `SecurityConfig` 빈), `SignupRequest`/`LoginRequest`/`AuthTokenResponse`(Task 5)
- Produces: `AuthService(UserRepository, RefreshTokenRepository, PasswordEncoder, JwtTokenProvider, JwtProperties, Clock)`,
  `AuthTokenResponse signup(SignupRequest)`, `AuthTokenResponse login(LoginRequest)` — Task 7이 같은 클래스에 `refresh`/`logout` 추가

- [ ] **Step 1: 실패하는 AuthServiceTest 작성 (signup/login 케이스)**

`server/src/test/java/studio/thumbsup/server/auth/AuthServiceTest.java`:

```java
package studio.thumbsup.server.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;
import studio.thumbsup.server.auth.dto.AuthTokenResponse;
import studio.thumbsup.server.auth.dto.LoginRequest;
import studio.thumbsup.server.auth.dto.SignupRequest;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.security.JwtProperties;
import studio.thumbsup.server.common.security.JwtTokenProvider;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-07T00:00:00Z");

    @Mock
    private UserRepository userRepository;

    @Mock
    private RefreshTokenRepository refreshTokenRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtTokenProvider jwtTokenProvider;

    private AuthService authService;

    @BeforeEach
    void setUp() {
        JwtProperties jwtProperties = new JwtProperties("test-secret", Duration.ofMinutes(30), Duration.ofDays(14));
        Clock clock = Clock.fixed(NOW, ZoneOffset.UTC);
        authService = new AuthService(
                userRepository, refreshTokenRepository, passwordEncoder, jwtTokenProvider, jwtProperties, clock);
    }

    @Test
    void 이메일이_중복이면_USER_EMAIL_DUPLICATED() {
        given(userRepository.existsByEmail("a@test.com")).willReturn(true);

        assertThatThrownBy(() -> authService.signup(new SignupRequest("a@test.com", "password1")))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorType())
                        .isEqualTo(AuthErrorType.USER_EMAIL_DUPLICATED));
    }

    @Test
    void 회원가입_성공시_유저를_생성하고_기존_토큰_정리_후_신규_토큰을_발급한다() {
        given(userRepository.existsByEmail("a@test.com")).willReturn(false);
        given(passwordEncoder.encode("password1")).willReturn("hashed");
        given(userRepository.save(any(User.class))).willReturn(AuthFixture.user(1L, "a@test.com", "hashed"));
        given(jwtTokenProvider.createAccessToken(1L)).willReturn("access-token");

        AuthTokenResponse response = authService.signup(new SignupRequest("a@test.com", "password1"));

        assertThat(response.accessToken()).isEqualTo("access-token");
        assertThat(response.refreshToken()).isNotBlank();
        verify(refreshTokenRepository).deleteByUserId(1L);
        verify(refreshTokenRepository).save(any(RefreshToken.class));
    }

    @Test
    void 존재하지_않는_이메일로_로그인하면_INVALID_CREDENTIALS() {
        given(userRepository.findByEmail("nobody@test.com")).willReturn(Optional.empty());

        assertThatThrownBy(() -> authService.login(new LoginRequest("nobody@test.com", "password1")))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorType())
                        .isEqualTo(AuthErrorType.INVALID_CREDENTIALS));
    }

    @Test
    void 비밀번호가_틀리면_INVALID_CREDENTIALS() {
        User user = AuthFixture.user(1L, "a@test.com", "hashed");
        given(userRepository.findByEmail("a@test.com")).willReturn(Optional.of(user));
        given(passwordEncoder.matches("wrong", "hashed")).willReturn(false);

        assertThatThrownBy(() -> authService.login(new LoginRequest("a@test.com", "wrong")))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorType())
                        .isEqualTo(AuthErrorType.INVALID_CREDENTIALS));
    }

    @Test
    void 로그인_성공시_토큰을_발급한다() {
        User user = AuthFixture.user(1L, "a@test.com", "hashed");
        given(userRepository.findByEmail("a@test.com")).willReturn(Optional.of(user));
        given(passwordEncoder.matches("password1", "hashed")).willReturn(true);
        given(jwtTokenProvider.createAccessToken(1L)).willReturn("access-token");

        AuthTokenResponse response = authService.login(new LoginRequest("a@test.com", "password1"));

        assertThat(response.accessToken()).isEqualTo("access-token");
        assertThat(response.refreshToken()).isNotBlank();
    }
}
```

- [ ] **Step 2: 테스트 실행 → 컴파일 실패 확인**

Run: `./gradlew test --tests "studio.thumbsup.server.auth.AuthServiceTest"`
Expected: FAIL — `AuthService` 클래스가 없어 컴파일 에러

- [ ] **Step 3: AuthService 구현 (signup/login)**

`server/src/main/java/studio/thumbsup/server/auth/AuthService.java`:

```java
package studio.thumbsup.server.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import studio.thumbsup.server.auth.dto.AuthTokenResponse;
import studio.thumbsup.server.auth.dto.LoginRequest;
import studio.thumbsup.server.auth.dto.SignupRequest;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.exception.CommonErrorType;
import studio.thumbsup.server.common.security.JwtProperties;
import studio.thumbsup.server.common.security.JwtTokenProvider;

/**
 * ⚠️ 클래스 레벨 {@code @Transactional(readOnly = true)}는 조회 전용 기본값이다.
 * <b>쓰기 메서드에는 반드시 {@code @Transactional}(readOnly=false)를 오버라이드한다</b>.
 */
@Service
@Transactional(readOnly = true)
public class AuthService {

    private static final int REFRESH_TOKEN_BYTE_LENGTH = 32;

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;
    private final JwtProperties jwtProperties;
    private final Clock clock;
    private final SecureRandom secureRandom = new SecureRandom();

    public AuthService(
            UserRepository userRepository,
            RefreshTokenRepository refreshTokenRepository,
            PasswordEncoder passwordEncoder,
            JwtTokenProvider jwtTokenProvider,
            JwtProperties jwtProperties,
            Clock clock) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtTokenProvider = jwtTokenProvider;
        this.jwtProperties = jwtProperties;
        this.clock = clock;
    }

    @Transactional
    public AuthTokenResponse signup(SignupRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new BusinessException(AuthErrorType.USER_EMAIL_DUPLICATED);
        }
        User user = userRepository.save(User.create(request.email(), passwordEncoder.encode(request.password())));
        return issueTokens(user.getId());
    }

    @Transactional
    public AuthTokenResponse login(LoginRequest request) {
        User user = userRepository
                .findByEmail(request.email())
                .orElseThrow(() -> new BusinessException(AuthErrorType.INVALID_CREDENTIALS));
        if (!passwordEncoder.matches(request.password(), user.getPassword())) {
            throw new BusinessException(AuthErrorType.INVALID_CREDENTIALS);
        }
        return issueTokens(user.getId());
    }

    private AuthTokenResponse issueTokens(Long userId) {
        refreshTokenRepository.deleteByUserId(userId); // 회전 — 유저당 refresh token 1개 유지
        String accessToken = jwtTokenProvider.createAccessToken(userId);
        String rawRefreshToken = generateRefreshToken();
        Instant expiresAt = clock.instant().plus(jwtProperties.refreshTokenValidity());
        refreshTokenRepository.save(RefreshToken.create(userId, hash(rawRefreshToken), expiresAt));
        return AuthTokenResponse.of(accessToken, rawRefreshToken);
    }

    private String generateRefreshToken() {
        byte[] bytes = new byte[REFRESH_TOKEN_BYTE_LENGTH];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String hash(String rawToken) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(rawToken.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            // SHA-256은 JDK 표준 알고리즘이라 실제로 발생하지 않는다 — 표준 예외 대신 BusinessException으로 감싼다(ArchUnit)
            throw new BusinessException(CommonErrorType.INTERNAL_ERROR, e);
        }
    }
}
```

- [ ] **Step 4: 테스트 실행**

Run: `./gradlew test --tests "studio.thumbsup.server.auth.AuthServiceTest"`
Expected: PASS (5 tests)

- [ ] **Step 5: 커밋**

```bash
git add server/src/main/java/studio/thumbsup/server/auth/AuthService.java server/src/test/java/studio/thumbsup/server/auth/AuthServiceTest.java
git commit -m "feat(server): AuthService signup/login 구현 (#44)"
```

---

### Task 7: AuthService — refresh/logout

**Files:**
- Modify: `server/src/main/java/studio/thumbsup/server/auth/AuthService.java`
- Modify: `server/src/test/java/studio/thumbsup/server/auth/AuthServiceTest.java`

**Interfaces:**
- Consumes: `RefreshRequest`(Task 5), `AuthFixture.refreshToken(...)`(Task 1)
- Produces: `AuthTokenResponse refresh(RefreshRequest)`, `void logout(Long userId)` — Task 8의 `AuthController`가 호출

- [ ] **Step 1: AuthServiceTest에 실패하는 테스트 추가**

`AuthServiceTest.java`의 import에 추가:

```java
import studio.thumbsup.server.auth.dto.RefreshRequest;
```

클래스 마지막(닫는 `}` 앞)에 추가:

```java

    @Test
    void 존재하지_않는_refresh_token은_INVALID_REFRESH_TOKEN() {
        given(refreshTokenRepository.findByTokenHash(any())).willReturn(Optional.empty());

        assertThatThrownBy(() -> authService.refresh(new RefreshRequest("raw-token")))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorType())
                        .isEqualTo(AuthErrorType.INVALID_REFRESH_TOKEN));
    }

    @Test
    void 만료된_refresh_token은_INVALID_REFRESH_TOKEN() {
        RefreshToken expired = AuthFixture.refreshToken(1L, 1L, "hash", NOW.minus(Duration.ofDays(1)));
        given(refreshTokenRepository.findByTokenHash(any())).willReturn(Optional.of(expired));

        assertThatThrownBy(() -> authService.refresh(new RefreshRequest("raw-token")))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorType())
                        .isEqualTo(AuthErrorType.INVALID_REFRESH_TOKEN));
    }

    @Test
    void refresh_성공시_기존_토큰을_회전하고_신규_토큰을_발급한다() {
        RefreshToken valid = AuthFixture.refreshToken(1L, 7L, "hash", NOW.plus(Duration.ofDays(1)));
        given(refreshTokenRepository.findByTokenHash(any())).willReturn(Optional.of(valid));
        given(jwtTokenProvider.createAccessToken(7L)).willReturn("new-access-token");

        AuthTokenResponse response = authService.refresh(new RefreshRequest("raw-token"));

        assertThat(response.accessToken()).isEqualTo("new-access-token");
        assertThat(response.refreshToken()).isNotBlank();
        verify(refreshTokenRepository).deleteByUserId(7L);
        verify(refreshTokenRepository).save(any(RefreshToken.class));
    }

    @Test
    void logout은_유저의_refresh_token을_모두_삭제한다() {
        authService.logout(7L);

        verify(refreshTokenRepository).deleteByUserId(7L);
    }
```

- [ ] **Step 2: 테스트 실행 → 컴파일 실패 확인**

Run: `./gradlew test --tests "studio.thumbsup.server.auth.AuthServiceTest"`
Expected: FAIL — `authService.refresh(...)`/`authService.logout(...)` 메서드가 없어 컴파일 에러

- [ ] **Step 3: AuthService에 refresh/logout 추가**

`AuthService.java`의 import에 추가:

```java
import studio.thumbsup.server.auth.dto.RefreshRequest;
```

`login` 메서드 다음에 추가:

```java

    @Transactional
    public AuthTokenResponse refresh(RefreshRequest request) {
        RefreshToken stored = refreshTokenRepository
                .findByTokenHash(hash(request.refreshToken()))
                .orElseThrow(() -> new BusinessException(AuthErrorType.INVALID_REFRESH_TOKEN));
        if (stored.isExpired(clock)) {
            throw new BusinessException(AuthErrorType.INVALID_REFRESH_TOKEN);
        }
        return issueTokens(stored.getUserId());
    }

    @Transactional
    public void logout(Long userId) {
        refreshTokenRepository.deleteByUserId(userId);
    }
```

- [ ] **Step 4: 테스트 실행**

Run: `./gradlew test --tests "studio.thumbsup.server.auth.AuthServiceTest"`
Expected: PASS (9 tests)

- [ ] **Step 5: 커밋**

```bash
git add server/src/main/java/studio/thumbsup/server/auth/AuthService.java server/src/test/java/studio/thumbsup/server/auth/AuthServiceTest.java
git commit -m "feat(server): AuthService refresh/logout 구현 (#44)"
```

---

### Task 8: AuthController

**Files:**
- Create: `server/src/main/java/studio/thumbsup/server/auth/AuthController.java`
- Test: `server/src/test/java/studio/thumbsup/server/auth/AuthControllerTest.java`

**Interfaces:**
- Consumes: `AuthService`(Task 6·7 완성본), `SignupRequest`/`LoginRequest`/`RefreshRequest`/`AuthTokenResponse`(Task 5)
- Produces: `POST /api/v1/auth/{signup,login,refresh,logout}` — Task 9에서 `SecurityConfig`가 이 경로들을 참조

- [ ] **Step 1: 실패하는 AuthControllerTest 작성**

`server/src/test/java/studio/thumbsup/server/auth/AuthControllerTest.java`:

```java
package studio.thumbsup.server.auth;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.method.annotation.AuthenticationPrincipalArgumentResolver;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import studio.thumbsup.server.auth.dto.AuthTokenResponse;
import studio.thumbsup.server.auth.dto.LoginRequest;
import studio.thumbsup.server.auth.dto.RefreshRequest;
import studio.thumbsup.server.auth.dto.SignupRequest;
import studio.thumbsup.server.common.exception.BusinessException;
import studio.thumbsup.server.common.exception.GlobalExceptionHandler;

/** Controller 슬라이스 테스트 — standalone MockMvc로 요청/응답 계약만 검증한다 (피라미드 2층). */
@ExtendWith(MockitoExtension.class)
class AuthControllerTest {

    @Mock
    private AuthService authService;

    private MockMvc mockMvc;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @BeforeEach
    void setUp() {
        // @AuthenticationPrincipal 해석기를 명시 등록 — standalone은 Boot 자동설정이 없어 기본 등록되지 않는다
        mockMvc = MockMvcBuilders.standaloneSetup(new AuthController(authService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .setMessageConverters(new MappingJackson2HttpMessageConverter(objectMapper))
                .setCustomArgumentResolvers(new AuthenticationPrincipalArgumentResolver())
                .build();
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void 회원가입_성공시_201과_토큰을_반환한다() throws Exception {
        given(authService.signup(any())).willReturn(new AuthTokenResponse("access-token", "refresh-token"));

        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new SignupRequest("a@test.com", "password1"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.code").value("SUCCESS"))
                .andExpect(jsonPath("$.data.accessToken").value("access-token"))
                .andExpect(jsonPath("$.data.refreshToken").value("refresh-token"));
    }

    @Test
    void 이메일_형식이_아니면_INVALID_INPUT() throws Exception {
        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new SignupRequest("not-an-email", "password1"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_INPUT"));
    }

    @Test
    void 비밀번호가_8자_미만이면_INVALID_INPUT() throws Exception {
        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new SignupRequest("a@test.com", "short"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_INPUT"));
    }

    @Test
    void 이메일이_중복이면_409_USER_EMAIL_DUPLICATED() throws Exception {
        given(authService.signup(any())).willThrow(new BusinessException(AuthErrorType.USER_EMAIL_DUPLICATED));

        mockMvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new SignupRequest("a@test.com", "password1"))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("USER_EMAIL_DUPLICATED"));
    }

    @Test
    void 로그인_성공시_200과_토큰을_반환한다() throws Exception {
        given(authService.login(any())).willReturn(new AuthTokenResponse("access-token", "refresh-token"));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new LoginRequest("a@test.com", "password1"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.accessToken").value("access-token"));
    }

    @Test
    void 로그인_실패시_401_INVALID_CREDENTIALS() throws Exception {
        given(authService.login(any())).willThrow(new BusinessException(AuthErrorType.INVALID_CREDENTIALS));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new LoginRequest("a@test.com", "wrong"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    void refresh_성공시_200과_회전된_토큰을_반환한다() throws Exception {
        given(authService.refresh(any())).willReturn(new AuthTokenResponse("new-access", "new-refresh"));

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new RefreshRequest("old-refresh"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.accessToken").value("new-access"));
    }

    @Test
    void refresh_실패시_401_INVALID_REFRESH_TOKEN() throws Exception {
        given(authService.refresh(any())).willThrow(new BusinessException(AuthErrorType.INVALID_REFRESH_TOKEN));

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new RefreshRequest("invalid"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_REFRESH_TOKEN"));
    }

    @Test
    void logout은_토큰의_userId로_서비스를_호출하고_200을_반환한다() throws Exception {
        // JwtAuthenticationFilter가 SecurityContext에 심는 것과 동일한 형태로 인증 컨텍스트를 미리 채운다
        SecurityContextHolder.getContext()
                .setAuthentication(new UsernamePasswordAuthenticationToken(7L, null, List.of()));

        mockMvc.perform(post("/api/v1/auth/logout"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value("SUCCESS"))
                .andExpect(jsonPath("$.data").doesNotExist());

        verify(authService).logout(7L);
    }
}
```

- [ ] **Step 2: 테스트 실행 → 컴파일 실패 확인**

Run: `./gradlew test --tests "studio.thumbsup.server.auth.AuthControllerTest"`
Expected: FAIL — `AuthController` 클래스가 없어 컴파일 에러

- [ ] **Step 3: AuthController 구현**

`server/src/main/java/studio/thumbsup/server/auth/AuthController.java`:

```java
package studio.thumbsup.server.auth;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import studio.thumbsup.server.auth.dto.AuthTokenResponse;
import studio.thumbsup.server.auth.dto.LoginRequest;
import studio.thumbsup.server.auth.dto.RefreshRequest;
import studio.thumbsup.server.auth.dto.SignupRequest;
import studio.thumbsup.server.common.response.ApiResponse;

/**
 * 컨트롤러는 얇게 — 검증(어노테이션)·호출·envelope 감싸기만 한다.
 * signup/login/refresh는 SecurityConfig에서 공개 경로, logout은 인증 필요(Authorization 헤더) — Task 9.
 */
@Tag(name = "Auth", description = "로그인 인증")
@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @Operation(summary = "회원가입", description = "이메일 중복 시 code=USER_EMAIL_DUPLICATED (409)")
    @ResponseStatus(HttpStatus.CREATED)
    @PostMapping("/signup")
    public ApiResponse<AuthTokenResponse> signup(@Valid @RequestBody SignupRequest request) {
        return ApiResponse.success(authService.signup(request));
    }

    @Operation(summary = "로그인", description = "실패 시 code=INVALID_CREDENTIALS (401) — 원인 구분 없음")
    @PostMapping("/login")
    public ApiResponse<AuthTokenResponse> login(@Valid @RequestBody LoginRequest request) {
        return ApiResponse.success(authService.login(request));
    }

    @Operation(summary = "토큰 재발급", description = "회전 방식 — 이전 refreshToken 즉시 무효화. 실패 시 code=INVALID_REFRESH_TOKEN (401)")
    @PostMapping("/refresh")
    public ApiResponse<AuthTokenResponse> refresh(@Valid @RequestBody RefreshRequest request) {
        return ApiResponse.success(authService.refresh(request));
    }

    @Operation(summary = "로그아웃", description = "Authorization 헤더의 access token으로 유저를 식별해 refresh token을 폐기")
    @PostMapping("/logout")
    public ApiResponse<Void> logout(@AuthenticationPrincipal Long userId) {
        authService.logout(userId);
        return ApiResponse.success();
    }
}
```

- [ ] **Step 4: 테스트 실행**

Run: `./gradlew test --tests "studio.thumbsup.server.auth.AuthControllerTest"`
Expected: PASS (9 tests)

- [ ] **Step 5: 커밋**

```bash
git add server/src/main/java/studio/thumbsup/server/auth/AuthController.java server/src/test/java/studio/thumbsup/server/auth/AuthControllerTest.java
git commit -m "feat(server): AuthController 4개 엔드포인트 구현 (#44)"
```

---

### Task 9: SecurityConfig — logout 인증 강제

**Files:**
- Modify: `server/src/main/java/studio/thumbsup/server/common/config/SecurityConfig.java`

**Interfaces:**
- Consumes: 없음 (경로 문자열만 변경)
- Produces: `/api/v1/auth/logout`이 `anyRequest().authenticated()` 규칙에 포함됨 (공개 경로 목록에서 제외)

- [ ] **Step 1: PUBLIC_PATHS 수정**

`server/src/main/java/studio/thumbsup/server/common/config/SecurityConfig.java`에서 다음을 찾는다:

```java
    private static final String[] PUBLIC_PATHS = {
        "/actuator/health", "/swagger-ui.html", "/swagger-ui/**", "/v3/api-docs/**", "/api/v1/auth/**",
    };
```

다음으로 교체한다 (logout은 제외 — 인증 필요):

```java
    private static final String[] PUBLIC_PATHS = {
        "/actuator/health",
        "/swagger-ui.html",
        "/swagger-ui/**",
        "/v3/api-docs/**",
        "/api/v1/auth/signup",
        "/api/v1/auth/login",
        "/api/v1/auth/refresh",
    };
```

- [ ] **Step 2: 기존 테스트 회귀 확인 (SecurityConfig 자체 단위 테스트는 없음 — 전체 스위트로 컴파일/컨텍스트 확인)**

Run: `./gradlew test --tests "studio.thumbsup.server.ThumbsupServerApplicationTests"`
Expected: PASS

- [ ] **Step 3: 커밋**

```bash
git add server/src/main/java/studio/thumbsup/server/common/config/SecurityConfig.java
git commit -m "fix(server): logout 엔드포인트에 인증 강제 (#44)"
```

---

### Task 10: 전체 빌드 검증 + 수동 E2E

**Files:** 없음 (검증 전용 태스크)

- [ ] **Step 1: 전체 빌드 (테스트+ArchUnit+Spotless+Checkstyle)**

Run: `./gradlew build`
Expected: BUILD SUCCESSFUL — 실패 시 Spotless는 `./gradlew spotlessApply`로 자동 정리 후 재실행

- [ ] **Step 2: 로컬 서버 기동**

Run: `docker compose up --build -d`
Expected: `http://localhost:8080/actuator/health` → `{"status":"UP"}`

- [ ] **Step 3: 회원가입 → 로그인 → refresh 회전 → 이전 refresh 재사용 실패 → logout → logout 후 refresh 실패, 전체 흐름 curl로 확인**

```bash
# 1) 회원가입 — 201 + 토큰
curl -i -X POST http://localhost:8080/api/v1/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"email":"e2e@test.com","password":"password1"}'

# 2) 로그인 — 200 + 토큰 (아래 응답의 refreshToken을 REFRESH1로 기록)
curl -i -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"e2e@test.com","password":"password1"}'

# 3) refresh — 200 + 새 토큰 (REFRESH2로 기록), REFRESH1은 이제 무효
curl -i -X POST http://localhost:8080/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refreshToken":"<REFRESH1>"}'

# 4) REFRESH1 재사용 — 401 INVALID_REFRESH_TOKEN 기대 (회전 확인)
curl -i -X POST http://localhost:8080/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refreshToken":"<REFRESH1>"}'

# 5) logout 시도 — Authorization 헤더 없이 401 UNAUTHORIZED 기대 (인증 강제 확인, Task 9)
curl -i -X POST http://localhost:8080/api/v1/auth/logout

# 6) logout — 2)의 accessToken으로 200 기대
curl -i -X POST http://localhost:8080/api/v1/auth/logout \
  -H "Authorization: Bearer <ACCESS_TOKEN>"

# 7) logout 후 REFRESH2로 refresh 시도 — 401 INVALID_REFRESH_TOKEN 기대 (폐기 확인)
curl -i -X POST http://localhost:8080/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refreshToken":"<REFRESH2>"}'
```

Expected: 1)~7) 모두 위 주석의 status/code와 일치

- [ ] **Step 4: Swagger UI에서 계약 확인**

Run: 브라우저로 `http://localhost:8080/swagger-ui.html` 접속
Expected: `Auth` 태그 아래 4개 엔드포인트가 요청/응답 스키마와 에러 코드 설명과 함께 노출됨

- [ ] **Step 5: docker compose 정리**

```bash
docker compose down
```