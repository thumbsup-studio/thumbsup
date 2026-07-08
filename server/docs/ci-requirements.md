# CI/CD 요구사항 명세 (인수인계용)

CI/CD·인프라 담당자가 파이프라인을 구성할 때 필요한 서버(`server/`) 쪽 요구사항이다.
**현재 CI는 없다** — 이 명세 기준으로 GitHub Actions를 작성하면 된다.

## 1. PR 체크 (필수 2개)

품질 강제 로직은 전부 Gradle 빌드에 내장되어 있으므로, CI는 호출만 하면 된다.

| 체크 | 커맨드 | 포함 내용 |
|------|--------|-----------|
| 빌드+테스트 | `./gradlew --no-daemon build` (server/ 에서) | 컴파일 · 단위/통합 테스트 · **ArchUnit 아키텍처 규칙** · Spotless 포맷 · Checkstyle |
| 시크릿 스캔 | gitleaks | 하드코딩 시크릿 검출 (레포의 gitleaks 설정 사용) |

- 통합 테스트는 **Testcontainers**로 MySQL 컨테이너를 띄운다 → CI 러너에 **Docker 필요** (ubuntu-latest 기본 지원).
- 테스트는 `test` profile fixture 값을 사용한다. CI는 `/thumbsup/local/` 또는 `/thumbsup/prod/` SSM을 읽지 않는다.
- 개발자는 PR 전 로컬에서 `./gradlew --no-daemon spotlessApply build`로 포맷 적용과 빌드를 함께 확인한다.
- Java **21** (Temurin 권장), Gradle 캐시 활성화 권장.
- 트리거: `server/**` 변경이 있는 PR (frontend 파이프라인은 별도).

## 2. 브랜치 보호 (GitHub 설정)

| 항목 | 값 |
|------|-----|
| main 직접 push | 금지 (PR로만) |
| 필수 상태 체크 | 위 PR 체크 2개 (CI 생성 후 등록) |
| 병합 방식 | **Squash merge** (CONTRIBUTING.md 컨벤션) |

## 3. 배포 (main 병합 시)

앱은 12-factor/컨테이너 독립적으로 만들어져 있어 컴퓨트 플랫폼 선택은 자유다.

| 항목 | 값 |
|------|-----|
| 이미지 빌드 | `server/Dockerfile` (Phase 2에서 추가 예정) |
| 헬스체크 | `GET /actuator/health` |
| 프로파일 | 컨테이너 환경변수 `SPRING_PROFILES_ACTIVE=prod` |
| 설정/시크릿 | 앱이 부팅 시 SSM `/thumbsup/prod/*`에서 직접 로딩 — **파이프라인이 시크릿을 다룰 필요 없음** ([env-guide.md](env-guide.md)) |
| 실행 Role 권한 | `ssm:GetParameters`/`GetParametersByPath` + `kms:Decrypt` (리소스 `/thumbsup/prod/*` 한정, 읽기 전용) |
| AWS 인증 | GitHub Actions → **OIDC로 IAM Role 임시 위임** (장기 Access Key를 GitHub Secrets에 저장하지 않기) |
| DB | MySQL — 버전은 `server/docker-compose.yml`에 고정된 버전과 **동일하게** (로컬↔운영 패리티) |
| DB 마이그레이션 | 앱 부팅 시 Flyway가 자동 적용 — 별도 마이그레이션 스텝 불필요 |
| Swagger/OpenAPI | 운영에서 활성화하되 `/swagger-ui/**`, `/v3/api-docs/**`는 SSM 주입 계정으로 Basic Auth 보호 |

## 4. 서버 팀과 합의 필요한 항목

- ECR 리포지토리 이름 / 배포 트리거 방식 (자동 vs 수동 승인)
- prod CORS 허용 도메인 (프론트 배포 도메인 확정 시)
- Actuator 노출 범위 (기본: `health`만 외부 노출)
