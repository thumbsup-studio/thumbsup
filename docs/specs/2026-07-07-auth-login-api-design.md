# 로그인 인증 API 디자인 — #44

- **날짜**: 2026-07-07
- **상태**: 초안 (사용자 리뷰 대기 — 커밋 안 함)
- **관련 이슈**: [#44 feat(server): 로그인 인증 API — 세션/토큰 발급 (소셜 검증 optional)](https://github.com/thumbsup-studio/thumbsup/issues/44)
- **연계**: [#1 feat(app): 로그인](https://github.com/thumbsup-studio/thumbsup/issues/1) (FE, 방식 합의 대상)

## 배경과 목표

#82에서 JWT 인증 인프라(`JwtTokenProvider`, `JwtAuthenticationFilter`, `SecurityConfig`)가 이미 들어왔다.
`docs/api-standard.md` §8에 인증 방식(JWT, access 30분 / refresh 14일 DB 저장+회전)이 계약으로
확정돼 있어, 이슈 #44의 "세션 vs JWT 합의" 항목은 이미 해결된 상태다.

이번 작업 범위는 **자체 로그인(이메일/비밀번호)만** — 소셜 로그인(Apple/Google/Kakao)은
이슈에서 optional이며 M3로 분류되어 있어 이번 스코프에서 제외한다.

## 결정 기록

| 결정 | 선택 | 근거 |
|------|------|------|
| 엔드포인트 구조 | signup/login 분리 | 이슈 #1 테스트케이스(TC-1-06 로그인↔가입 토글, TC-1-12 중복가입 차단)가 FE에서 두 폼을 분리해 씀을 시사 |
| 이번 PR 범위 | signup + login + refresh + logout 전부 포함 | `api-standard.md`에 refresh 회전·로그아웃 폐기 정책이 이미 계약으로 명시돼 있고, `JwtTokenProvider` 주석도 "refresh는 auth feature 담당"이라 명시 |
| 패키지 구조 | `auth` 단일 feature (User 엔티티 포함) | ArchUnit이 feature 간 의존을 전면 금지(common 제외) — User를 분리하면 auth가 참조할 방법이 없음. 아직 User를 참조할 다른 feature가 없으므로 지금은 합쳐두고, 필요해지면 그때 분리 방법을 재검토 |
| 테이블명 | `users` (복수, notice 컨벤션인 단수 예외) | `user`는 MySQL 예약어라 매 쿼리 백틱 필요 — 실용적 예외 |
| 비밀번호 정책 | 최소 8자, 문자 종류 제한 없음 | MVP 단순화. 복잡도 강제는 후속 이슈 |
| User 엔티티 필드 | email + password만 | 닉네임 등 프로필 필드는 온보딩 이슈(#17/#71) 스코프 |
| 로그인 실패 응답 | "이메일 없음"/"비밀번호 틀림" 구분 없이 `INVALID_CREDENTIALS` 단일 코드 | 계정 존재 여부 유추 방지 (OWASP 권고) |
| refresh 토큰 전달 방식 | body의 `refreshToken` 값 (Authorization 헤더 아님) | refresh는 **access token 만료 후** 호출되는 흐름이라 애초에 유효한 Authorization 헤더가 없음. OAuth2 표준도 동일(body/form 전달) |
| logout 인증 방식 | Authorization 헤더(access token) 기반, `@AuthenticationPrincipal` | `api-standard.md` §8 "서버는 항상 토큰에서 유저를 식별한다"는 전 API 공통 원칙과 정합성 우선. Access token 만료 후 로그아웃은 흔치 않은 엣지케이스이며, FE는 서버 응답과 무관하게 로컬 토큰을 삭제하므로 안전 |
| refresh token 저장 | 원문 미저장, SHA-256 해시만 DB 저장 | 탈취 시 DB만으로 토큰 재사용 불가 |
| refresh token 세션 수 | 유저당 1개 (rotation 시 기존 row 삭제 후 재생성) | 다중 기기 세션 지원은 스코프 밖 (YAGNI) |

## 아키텍처

```text
studio.thumbsup.server.auth/
├─ User.java                  (Entity — email, password, BaseEntity 상속)
├─ UserRepository.java
├─ RefreshToken.java          (Entity — userId, tokenHash, expiresAt)
├─ RefreshTokenRepository.java
├─ AuthController.java        (얇게 — 검증·호출·envelope만)
├─ AuthService.java           (@Transactional, 비즈니스 로직)
├─ AuthErrorType.java
└─ dto/
   ├─ SignupRequest.java      (email, password)
   ├─ LoginRequest.java       (email, password)
   ├─ RefreshRequest.java     (refreshToken)
   └─ AuthTokenResponse.java  (accessToken, refreshToken)
```

`notice/` 레퍼런스 패턴(정적 팩토리 `create()`, `@Transactional(readOnly=true)` 클래스 기본값 +
쓰기 메서드 오버라이드, ErrorType enum, DTO record)을 그대로 따른다.

### SecurityConfig 변경

현재 `PUBLIC_PATHS`가 `/api/v1/auth/**` 전체를 permitAll 처리하고 있어 logout도 인증 없이
통과된다. logout은 인증을 강제해야 하므로 공개 경로를 다음으로 좁힌다.

```text
"/api/v1/auth/signup", "/api/v1/auth/login", "/api/v1/auth/refresh"
```

`/api/v1/auth/logout`은 화이트리스트에서 빠지고, `authorizeHttpRequests`의 기본 규칙
(`anyRequest().authenticated()`)에 걸려 access token 검증이 자동 강제된다.

## 엔드포인트

| 메서드 | 경로 | 인증 | 성공 status | 설명 |
|---|---|---|---|---|
| POST | `/api/v1/auth/signup` | 불필요 | 201 | 이메일 중복 체크 → 유저 생성 → 토큰 발급 |
| POST | `/api/v1/auth/login` | 불필요 | 200 | 이메일/비밀번호 검증 → 토큰 발급 |
| POST | `/api/v1/auth/refresh` | 불필요(body의 refreshToken이 자격 증명) | 200 | refreshToken 검증 → 기존 토큰 폐기 + 신규 발급(회전) |
| POST | `/api/v1/auth/logout` | 필요(Authorization: Bearer) | 200 | `@AuthenticationPrincipal` userId로 해당 유저의 refresh token 폐기, data: null |

- signup/login/refresh 응답은 동일한 `AuthTokenResponse { accessToken, refreshToken }`.
- logout은 `ApiResponse.success()` (data null).
- 요청 DTO 검증: `@NotBlank`, `@Email`(email), `@Size(min = 8)`(password) — 실패 시 전역 핸들러가
  `INVALID_INPUT` + `data.fieldErrors`로 변환(기존 공통 처리, 추가 구현 불필요).

## 엔티티 · 마이그레이션

한 PR = 마이그레이션 1개 원칙에 따라 `V{yyyyMMddHHmmss}__create_auth_tables.sql` 하나에 두 테이블을 담는다.

```sql
CREATE TABLE users (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    email         VARCHAR(255) NOT NULL,
    password      VARCHAR(255) NOT NULL,
    created_at    DATETIME(6)  NOT NULL,
    updated_at    DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_users_email (email)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

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
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
```

- `refresh_token.user_id`는 JPA 연관관계가 아닌 값 컬럼(`Long userId`) + DB FK 제약
  (`dto-and-query-patterns.md` 크로스 도메인 참조 컨벤션과 동일한 방식을 같은 feature 내부에도 적용 —
  이후 User가 별도 feature로 분리될 가능성을 감안).
- `token_hash`는 SHA-256(원문 refresh token) — 원문은 DB에 저장하지 않고 응답에 1회만 노출.

## 에러 (AuthErrorType)

| code | HTTP | 상황 |
|---|---|---|
| `USER_EMAIL_DUPLICATED` | 409 | signup 시 이미 가입된 이메일 |
| `INVALID_CREDENTIALS` | 401 | login 실패 — 이메일 없음/비밀번호 틀림 구분 없이 동일 |
| `INVALID_REFRESH_TOKEN` | 401 | refresh 시 토큰이 없거나 만료·이미 회전되어 무효 |

## 보안 세부

- 비밀번호 해싱: 기존 `PasswordEncoder`(BCrypt) 빈 재사용.
- Access token: 기존 `JwtTokenProvider` 그대로 재사용(변경 없음).
- Refresh token: `SecureRandom` 32바이트 → Base64URL 인코딩 문자열(고엔트로피 불투명 토큰, JWT 아님).
- 설정: `JwtProperties`에 `refreshTokenValidity`(`Duration`) 필드 추가.
  `application.yml`에 `thumbsup.jwt.refresh-token-validity: 14d` 추가 (계약값 — `api-standard.md` §8과 동기화).
- Rotation: refresh 성공 시 기존 `refresh_token` row 삭제 + 신규 row insert, 새 accessToken +
  refreshToken 함께 반환. 이전 refreshToken 재사용 시 `INVALID_REFRESH_TOKEN`.
- Logout: 해당 유저의 `refresh_token` row 삭제(존재하지 않아도 200 — idempotent).

## 테스트 계획

`notice` 4종 패턴을 그대로 복제한다.

- `AuthServiceTest` (Mockito) — signup 중복/성공, login 성공/실패(이메일 없음·비번 틀림 모두 동일 코드),
  refresh 성공(회전 확인)/실패(무효·만료·이미 회전된 토큰 재사용), logout
- `AuthControllerTest` (standalone MockMvc) — DTO 검증 실패(400 INVALID_INPUT), 각 엔드포인트 성공 응답 형태,
  logout 미인증 시 401
- `AuthRepositoryTest` (@DataJpaTest + Testcontainers) — email UNIQUE 제약, token_hash 조회
- `AuthFixture`
- 런타임 E2E 확인(수동): signup → login → refresh(회전 확인, 이전 refresh 재사용 실패) → logout →
  로그아웃 후 refresh 실패