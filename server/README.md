# Thumbs Up Server

Java 21 · Spring Boot · MySQL · JPA · Gradle(Kotlin DSL).
코딩 규칙은 [CLAUDE.md](CLAUDE.md)(AI 자동 로딩 인덱스)와 [docs/](docs/)(정본), API 계약은 [../docs/](../docs/)를 본다.

## 실행

### FE 개발자 (Java 설치 불필요)

```bash
cd server && docker compose up --build
# → http://localhost:8080 에 로컬 API 서버 + MySQL이 뜬다
```

### 서버 개발자 (IDE/Gradle로 앱 실행)

```bash
cd server
docker compose up -d mysql   # DB만 컨테이너로
./gradlew bootRun            # 프로파일 미지정 = local
```

### 확인 URL

| 용도 | URL |
|------|-----|
| 헬스체크 | http://localhost:8080/actuator/health |
| Swagger UI (API 레퍼런스) | http://localhost:8080/swagger-ui.html |

## 품질 게이트 (로컬에서 전부 강제)

```bash
./gradlew build   # 컴파일 + 테스트(Testcontainers, Docker 필요) + Spotless + Checkstyle
./gradlew spotlessApply   # 포맷 위반 자동 수정
```

- **빌드 통과 전 PR 금지.** CI가 아직 없어도 이 한 줄이 가드레일이다.
- 테스트는 실제 MySQL(Testcontainers)로 돈다 — Docker Desktop이 켜져 있어야 한다.

## 시크릿 커밋 차단 (gitleaks, 1회 설정)

```bash
brew install gitleaks
git config core.hooksPath .githooks   # 레포 루트에서
```

## 프로파일

| 프로파일 | 용도 | 설정 소스 |
|----------|------|-----------|
| `local` (기본) | 개발 머신 | `application-local.yml` + docker compose MySQL |
| `prod` | AWS 운영 | SSM Parameter Store 주입 — [docs/env-guide.md](docs/env-guide.md) |
