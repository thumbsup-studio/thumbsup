# Thumbs Up Server

Java 21 · Spring Boot · MySQL · JPA · Gradle(Kotlin DSL).
코딩 규칙은 [CLAUDE.md](CLAUDE.md)(AI 자동 로딩 인덱스)와 [docs/](docs/)(정본), API 계약은 [../docs/](../docs/)를 본다.

## 실행

### FE 개발자

FE 개발자는 로컬 서버 실행/AWS 설정 대상이 아니다.
운영 API 문서는 `https://thumbsup-api.duckdns.org/swagger-ui.html`에서 Basic Auth로 확인한다.

### 서버 개발자 (IDE/Gradle로 앱 실행)

```bash
cd server
export AWS_PROFILE=thumbsup
export AWS_REGION=ap-northeast-2
docker compose up -d mysql   # DB만 컨테이너로
./gradlew bootRun            # 프로파일 미지정 = local
```

local profile은 `/thumbsup/local/` SSM 값을 읽는다. 자세한 절차는 [docs/local-development.md](docs/local-development.md)를 본다.

### 확인 URL

| 용도 | URL |
|------|-----|
| 헬스체크 | http://localhost:8080/actuator/health |
| Swagger UI (API 레퍼런스, Basic Auth 필요) | http://localhost:8080/swagger-ui.html |

## 품질 게이트 (로컬에서 전부 강제)

```bash
./gradlew --no-daemon spotlessApply build
```

- **빌드 통과 전 PR 금지.** CI가 아직 없어도 이 한 줄이 가드레일이다.
- 테스트는 실제 MySQL(Testcontainers)로 돈다 — Docker Desktop이 켜져 있어야 한다.
- Gradle 테스트는 `test` profile을 사용하며 AWS SSM을 읽지 않는다.

## 시크릿 커밋 차단 (gitleaks, 1회 설정)

```bash
brew install gitleaks
git config core.hooksPath .githooks   # 레포 루트에서
```

## 프로파일

| 프로파일 | 용도 | 설정 소스 |
|----------|------|-----------|
| `local` (기본) | 서버 개발자 개발 머신 | `application-local.yml` + docker compose MySQL + SSM `/thumbsup/local/` |
| `prod` | AWS 운영 | SSM `/thumbsup/prod/` — [docs/env-guide.md](docs/env-guide.md) |
| `test` | Gradle 테스트 | test fixture 값 + Testcontainers |
