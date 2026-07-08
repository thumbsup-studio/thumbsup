# 환경변수·시크릿 관리 가이드

서버(`server/`)의 설정·시크릿을 어디에 두고 어떻게 읽는지 정의한다.
**코드와 깃에는 시크릿이 단 한 줄도 들어가지 않는다** — 이 원칙이 전부다.

## 1. 프로파일 구조

서버 런타임 profile은 `local`과 `prod` 2개만 유지한다. 별도 `dev` 서버/profile은 만들지 않는다.

| 프로파일 | 용도 | 설정 소스 |
|----------|------|-----------|
| `local` (기본) | 서버 개발자 로컬 머신 | `application-local.yml` + docker-compose MySQL + SSM `/thumbsup/local/` |
| `prod` | AWS 운영 | `application-prod.yml` + SSM `/thumbsup/prod/` |

- `application.yml` = 전 환경 공통 설정만 둔다.
- `application-local.yml` = 로컬 DB 고정값 + `/thumbsup/local/` SSM import.
- `application-prod.yml` = 운영 DB/CORS/시크릿을 `/thumbsup/prod/` SSM에서 주입.
- `test` profile은 서버 런타임 profile이 아니라 Gradle 테스트 전용 설정이다.
- `src/test/resources/application-test.yml`은 fixture 값과 Testcontainers 연결에만 사용한다.
- 테스트는 AWS SSM을 읽지 않는다. 회귀 테스트는 Docker/Testcontainers만 필요해야 한다.

## 2. Parameter Store 정책

Spring Cloud AWS의 `spring.config.import=aws-parameterstore:/path/`로 SSM 값을 런타임에 읽는다.
경로가 없거나 권한이 없으면 부팅에 실패한다. 이 fail-fast 동작이 의도다.

| 환경 | import 경로 | 원칙 |
|------|-------------|------|
| local | `/thumbsup/local/` | 서버 개발자가 공유하는 로컬 전용 secret/config만 둔다. prod 값 금지. |
| prod | `/thumbsup/prod/` | 운영 DB/JWT/CORS/Swagger 값을 둔다. local 값 금지. |

로컬 DB 접속정보는 SSM으로 빼지 않는다. `docker-compose.yml`과 `application-local.yml`의 고정값을 유지해
로컬 실행 절차를 단순하게 둔다.

## 3. 필수 SSM 키

아래 키는 `application-local.yml`, `application-prod.yml`이 직접 참조하는 값이다.
`SPRING_PROFILES_ACTIVE`, `AWS_PROFILE`, `AWS_REGION`은 SSM 키가 아니라 실행 환경에서 주입하는 값이다.
로컬 DB 접속정보와 local CORS는 SSM으로 빼지 않는다.

| 경로 | 타입 | 용도 |
|------|------|------|
| `/thumbsup/local/JWT_SECRET` | SecureString | local JWT 서명 키 |
| `/thumbsup/local/SWAGGER_USERNAME` | String | local Swagger Basic Auth username |
| `/thumbsup/local/SWAGGER_PASSWORD` | SecureString | local Swagger Basic Auth password |
| `/thumbsup/prod/DB_URL` | String | prod JDBC URL |
| `/thumbsup/prod/DB_USERNAME` | String | prod DB username |
| `/thumbsup/prod/DB_PASSWORD` | SecureString | prod DB password |
| `/thumbsup/prod/JWT_SECRET` | SecureString | prod JWT 서명 키 |
| `/thumbsup/prod/CORS_ALLOWED_ORIGIN_PATTERNS` | String | prod CORS origin patterns |
| `/thumbsup/prod/SWAGGER_USERNAME` | String | prod Swagger Basic Auth username |
| `/thumbsup/prod/SWAGGER_PASSWORD` | SecureString | prod Swagger Basic Auth password |

`/thumbsup/local/*`과 `/thumbsup/prod/*`는 서로 복사하지 않는다. local은 로컬 전용 값, prod는 운영값이다.

## 4. 서버 개발자 AWS 설정

FE 개발자는 서버를 로컬에서 실행하지 않으므로 AWS 설정 대상이 아니다.
서버 개발자는 로컬 실행 전에 AWS 권한과 profile을 준비한다.

```bash
# 예시: named profile 생성. SSO를 쓰는 팀이면 aws configure sso --profile thumbsup 를 사용한다.
aws configure --profile thumbsup

# 작업 셸에서 사용할 profile 지정
export AWS_PROFILE=thumbsup
export AWS_REGION=ap-northeast-2

# 권한 확인
aws sts get-caller-identity

# local SSM 조회 확인
aws ssm get-parameters-by-path \
  --path "/thumbsup/local/" \
  --with-decryption
```

이미 셸에 `AWS_ACCESS_KEY_ID`가 export되어 있으면 profile보다 우선할 수 있다.
프로필이 먹지 않으면 `env | grep AWS`로 확인한다.

## 5. 등록/수정 명령

```bash
# 등록
aws ssm put-parameter --profile thumbsup \
  --name "/thumbsup/local/JWT_SECRET" \
  --value "..." \
  --type SecureString

# 수정
aws ssm put-parameter --profile thumbsup \
  --name "/thumbsup/local/JWT_SECRET" \
  --value "..." \
  --type SecureString \
  --overwrite
```

민감값을 CLI 인자로 넣으면 셸 히스토리에 남을 수 있다. 등록 담당자는 히스토리 정책을 확인하고,
가능하면 AWS Console 또는 안전한 입력 경로를 사용한다.

## 6. Fail-fast 원칙

시크릿 프로퍼티에는 default 값을 두지 않는다.

허용 예시는 `${KEY}`처럼 값이 없으면 부팅에 실패하는 형태다.
금지 예시는 `${KEY:...}`처럼 default를 넣어 잘못된 값으로 조용히 기동하는 형태다.

새 설정은 가능하면 `@ConfigurationProperties` + Bean Validation으로 선언한다.
예: `JwtProperties`, `CorsProperties`, `SwaggerBasicAuthProperties`.

## 7. CORS origin pattern

운영 CORS는 `CORS_ALLOWED_ORIGIN_PATTERNS`로 주입한다.
Vercel PR preview는 배포마다 하위 도메인이 달라지므로 exact origin 목록이 아니라 Spring
`allowedOriginPatterns`를 쓴다.

```text
/thumbsup/prod/CORS_ALLOWED_ORIGIN_PATTERNS=https://thumbsup-app.vercel.app,https://*-thumbsup.vercel.app
```

- `https://thumbsup-app.vercel.app`: main 머지 시 프로덕션 FE
- `https://*-thumbsup.vercel.app`: 팀 slug로 끝나는 Vercel PR preview
- 서버는 `allowCredentials(true)`를 사용하므로 `*` 단독 origin은 금지한다.

## 8. 유출 방지

- gitleaks를 pre-commit 훅과 CI에 걸어 하드코딩 시크릿 커밋을 차단한다.
- `.env`, `.envrc`, AWS credential 파일은 커밋하지 않는다.
- PR 전 `git diff --cached`로 `JWT_SECRET`, `SWAGGER_PASSWORD`, `DB_PASSWORD`, access key가 섞이지 않았는지 확인한다.
