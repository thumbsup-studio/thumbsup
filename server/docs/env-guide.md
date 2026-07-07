# 환경변수·시크릿 관리 가이드

서버(`server/`)의 설정·시크릿을 어디에 두고 어떻게 읽는지 정의한다.
**코드와 깃에는 시크릿이 단 한 줄도 들어가지 않는다** — 이 원칙이 전부다.

## 1. 프로파일 구조 (local / prod 2개)

사이드프로젝트 특성상 dev 환경은 없다.

| 프로파일 | 용도 | 설정 소스 |
|----------|------|-----------|
| `local` | 각자 개발 머신 | `application-local.yml` + docker-compose MySQL. **AWS 불필요** |
| `prod` | AWS 운영 | 환경변수 + **SSM Parameter Store** 런타임 주입 |

- `application.yml` = 전 환경 공통 설정만 (envelope, JPA 공통 옵션 등)
- ⚠️ **SSM `spring.config.import`는 반드시 `application-prod.yml`에만 넣는다.**
  공통 `application.yml`에 넣으면 로컬 부팅이 AWS 자격증명을 요구하며 실패한다.

## 2. AWS SSM Parameter Store

### 왜 SSM인가
Standard tier(4KB 이하) 무료, 파라미터별 버전 히스토리(잘못 바꿔도 롤백 확인 가능), aws cli로 전체 라이프사이클 관리. Secrets Manager는 자동 로테이션이 필요해질 때 해당 값만 승격한다.

### 네이밍

```text
/thumbsup/prod/{KEY}     예) /thumbsup/prod/DB_PASSWORD
```

- 시크릿(비밀번호, JWT 키 등) = **SecureString** / 일반 설정 = String

### 등록/수정 (cli)

```bash
# 등록 (시크릿)
aws ssm put-parameter --profile thumbsup \
  --name "/thumbsup/prod/DB_PASSWORD" --value "..." --type SecureString

# 수정 (--overwrite 필수)
aws ssm put-parameter --profile thumbsup \
  --name "/thumbsup/prod/DB_PASSWORD" --value "..." --type SecureString --overwrite

# 일괄 조회
aws ssm get-parameters-by-path --profile thumbsup \
  --path "/thumbsup/prod/" --with-decryption
```

> 주의: 명령의 평문 값이 셸 히스토리에 남는다. 민감값 등록 시 명령 앞에 공백을 넣거나(HISTCONTROL), 등록 후 히스토리를 정리한다.

### Spring 연동 (런타임 주입)

- 의존성: `io.awspring.cloud:spring-cloud-aws-starter-parameter-store` (+ BOM `spring-cloud-aws-dependencies`, Boot 3.5 호환 버전)
- `application-prod.yml`:
  ```yaml
  spring:
    config:
      import: "aws-parameterstore:/thumbsup/prod/"
  ```
- 앱 코드는 `${DB_PASSWORD}` 참조만 하면 부팅 시 SSM에서 자동 주입된다.
- **CI에서 파라미터를 `.env`로 굽는 빌드타임 조회 금지** — 아티팩트/로그로 시크릿이 샌다.

### Fail-fast 원칙

시크릿 프로퍼티에 **default 값을 주지 않는다.**

```java
@Value("${JWT_SECRET}")        // ✅ 없으면 부팅 실패 — 안전
@Value("${JWT_SECRET:dev123}") // ❌ 금지 — 조용히 잘못된 값으로 뜸
```

## 3. 권한 (IAM) — 쓰기/읽기 분리

| 주체 | 권한 |
|------|------|
| 파라미터 등록 담당 1명 | `ssm:PutParameter` (SSO/IAM 사용자) |
| 앱 실행 Role (ECS Task 등) | **읽기 전용**: `ssm:GetParameters`/`GetParametersByPath` + `kms:Decrypt`, 리소스는 `/thumbsup/prod/*` 한정. PutParameter 없음 |
| GitHub Actions | 장기 키 저장 금지 — 필요 시 **OIDC로 IAM Role 임시 위임** |

## 4. 로컬 온보딩 (팀원 5명)

이미 다른 AWS 계정이 설정된 머신에서도 named profile로 공존 가능하다.

```bash
# 1) thumbsup 프로필 추가 (기존 default는 그대로)
aws configure --profile thumbsup     # Access Key / Secret / region: ap-northeast-2 (서울 — 가정값, 인프라 담당과 확인)

# 2) 프로젝트 폴더에서 자동 전환 — direnv
echo 'export AWS_PROFILE=thumbsup' > .envrc   # 커밋 금지 — 루트 .gitignore 무시 대상
direnv allow

# 3) 작업 전 계정 확인 습관
aws sts get-caller-identity
```

> 안 먹으면: 셸에 `AWS_ACCESS_KEY_ID`가 export되어 있으면 프로필보다 우선한다 — `env | grep AWS`로 확인.

## 5. 유출 방지

- **gitleaks**를 pre-commit 훅 + CI에 걸어 하드코딩 시크릿 커밋을 원천 차단한다 (AI 코드 생성 환경에서 특히 중요).
- `.env`, `.envrc`는 **루트 `.gitignore`에 반드시 포함해 커밋을 차단한다** (Phase 0 레포 정리 PR에 반영 — 머지 전이라면 로컬에서 커밋하지 않도록 주의). `.env.example`(키 이름만, 값 없음)로 필요한 키 목록을 공유한다.

## 6. CORS origin pattern

운영 CORS는 프론트 배포 origin을 SSM 파라미터 `CORS_ALLOWED_ORIGIN_PATTERNS`로 주입한다.
Vercel PR preview는 배포마다 하위 도메인이 달라지므로 exact origin 목록이 아니라 Spring `allowedOriginPatterns`를 쓴다.

```text
/thumbsup/prod/CORS_ALLOWED_ORIGIN_PATTERNS=https://thumbsup-app.vercel.app,https://*-thumbsup.vercel.app
```

- `https://thumbsup-app.vercel.app`: main 머지 시 프로덕션 FE
- `https://*-thumbsup.vercel.app`: 팀 slug로 끝나는 Vercel PR preview
- 세션/쿠키 인증 호환을 위해 서버는 `allowCredentials(true)`를 사용하므로 `*` 단독 origin은 금지한다.
