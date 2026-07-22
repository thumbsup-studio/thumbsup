# 프론트엔드 개발자를 위한 서버 개발 가이드

FE 개발자가 **서버 이슈까지 맡을 때** 필요한 것만 모았다. "무엇을 준비하고, 어떻게 띄우고, 어떤 스킬로 작업하는가"를 순서대로 담는다.

> 규칙·API 계약의 **정본**은 [`server/CLAUDE.md`](../server/CLAUDE.md)와 [`server/docs/`](../server/docs)다. 이 문서는 그리로 가는 **온보딩 지도**이지, 규칙을 다시 쓰지 않는다.

---

## 30초 빠른 시작

준비물([아래](#준비물))이 이미 갖춰졌다면:

```bash
# 1) 레포 최신화
git checkout main && git pull --ff-only

# 2) DB(MySQL) + 서버 기동 — Java 설치 불필요(Gradle이 JDK 21 자동 다운로드)
cd server
export AWS_PROFILE=thumbsup AWS_REGION=ap-northeast-2
docker compose up -d mysql
./gradlew bootRun

# 3) 다른 터미널에서 확인 — 응답 본문이 UP 이어야 성공
curl -fsS http://localhost:8080/actuator/health   # {"status":"UP"}
```

스키마와 초기 데이터(퀴즈·커리큘럼 시드)는 부팅 시 **Flyway가 자동 적용**한다. 수동 세팅 없이 바로 쓸 수 있는 서버가 뜬다.

---

## 준비물

| 준비물 | 왜 필요한가 | 비고 |
|---|---|---|
| **Docker Desktop** | MySQL 컨테이너(+선택적으로 앱 컨테이너) 실행 | 실행 상태여야 함 |
| **AWS CLI + `thumbsup` 프로파일** | 부팅 시 로컬 시크릿을 SSM에서 주입 | **SSM 읽기 + KMS decrypt** 권한 필요 ([아래](#aws-권한--부팅의-유일한-진짜-관문)) |
| ~~Java 21~~ | **불필요** | 첫 `./gradlew` 실행 시 JDK 21을 자동으로 내려받음(foojay) |
| IDE (IntelliJ 등) | 서버 코드 작성·디버깅 | 선택 — `bootRun`만 쓸 거면 없어도 됨 |

### AWS 권한 — 부팅의 유일한 진짜 관문

`application-local.yml`이 부팅 시 **아래 6개 값을 SSM에서 필수로 읽는다.** 하나라도 없으면 서버가 뜨지 않는다.

```text
/thumbsup/local/JWT_SECRET          (SecureString)
/thumbsup/local/SWAGGER_USERNAME
/thumbsup/local/SWAGGER_PASSWORD    (SecureString)
/thumbsup/local/ELICE_API_KEY       (SecureString)
/thumbsup/local/ELICE_QUIZ_BASE_URL
/thumbsup/local/ELICE_QUIZ_MODEL
```

- 관리자에게 `thumbsup` 프로파일용 **`ssm:GetParametersByPath`(`/thumbsup/local/*`) + `kms:Decrypt`** 권한을 요청한다.
- ⚠️ SecureString(위 3개)은 **KMS decrypt 권한이 없으면** `--with-decryption`이 실패해 부팅이 막힌다. **부팅 실패 1순위 원인.**
- DB 접속정보는 SSM이 아니라 `docker-compose.yml`·`application-local.yml`의 고정값이라 따로 세팅할 게 없다.

프로파일 확인:

```bash
aws configure --profile thumbsup          # 최초 1회 (SSO 조직이면 aws sso login)
export AWS_PROFILE=thumbsup AWS_REGION=ap-northeast-2
aws sts get-caller-identity
aws ssm get-parameters-by-path --path "/thumbsup/local/" --with-decryption --query "Parameters[].Name"
```

---

## 서버 띄우기 — 두 경로

| 경로 | 언제 | 명령 |
|---|---|---|
| **A. 호스트 실행 (권장)** | 서버 코드를 개발할 때 — IDE·디버거·핫리로드 | `./gradlew bootRun` |
| B. 풀 컨테이너 | 배포 이미지 동작만 확인할 때 | `docker compose up --build` |

두 경로 모두 로컬 SSM을 읽으므로 `thumbsup` 프로파일이 필요하다. B는 호스트의 `~/.aws`를 컨테이너에 읽기전용으로 마운트한다.

**확인 URL**

| 용도 | URL |
|---|---|
| 헬스체크 | `http://localhost:8080/actuator/health` |
| Swagger UI | `http://localhost:8080/swagger-ui.html` |
| OpenAPI JSON | `http://localhost:8080/v3/api-docs` |

Swagger는 로컬에서도 Basic Auth가 필요하다(계정은 SSM `SWAGGER_USERNAME`/`SWAGGER_PASSWORD`).

**종료**: `cd server && docker compose down` (DB 볼륨까지 지우려면 `-v`).

> 실행 절차의 정본은 [`server/docs/local-development.md`](../server/docs/local-development.md)다.

---

## 막힐 때

| 증상 | 먼저 확인할 것 |
|---|---|
| 부팅이 SSM에서 실패 | `AWS_PROFILE=thumbsup`·`AWS_REGION=ap-northeast-2`, `/thumbsup/local/*` 접근 + **KMS decrypt** 권한 |
| health가 2xx인데 뭔가 이상 | 본문 `status`가 `UP`인지까지 확인 (`{"status":"UP"}`) |
| 포트 충돌 | `lsof -nP -iTCP:3306 -sTCP:LISTEN`(MySQL), `:8080`(서버) |
| Docker 데몬 에러 | Docker Desktop 실행 후 `docker info` |

단계별 로컬 실행·트러블슈팅은 **`thumbsup-local-server` 스킬**이 안내한다("로컬 서버 띄워줘"로 트리거).

---

## 어떤 스킬을 쓰나

작업 대부분은 **스킬이 트리거**된다 — 아래 표현을 쓰면 해당 절차(형식·게이트)가 강제된다.

| 하려는 일 | 스킬 | 트리거 예 |
|---|---|---|
| 로컬 서버 실행·검증 | **thumbsup-local-server** | "로컬 서버 띄워줘" |
| 이슈 기반 서버 작업(설계→구현→PR) | **server-pipeline** | "43번 이슈 작업해" |
| 커밋 | **commit** | "커밋해줘" |
| PR 생성 | **pr** | "PR 올려줘" |
| PR 머지 | **merge** | "머지해줘" |

`server-pipeline`은 이슈 하나를 받아 브랜치 → ATDD/TDD 구현 → 게이트 → 리뷰 → PR까지 무정지로 진행하고, **계획 확정 1회만** 확인받는다.

---

## 서버 코드 규칙 (핵심만)

정본은 [`server/CLAUDE.md`](../server/CLAUDE.md). 자주 걸리는 4가지만 미리 안다:

1. **표준 예외 금지** — `IllegalArgumentException` 대신 `BusinessException(ErrorType)`. `ErrorType`은 feature별 enum.
2. **JPA 엔티티 직접 노출 금지** — API별 `record` DTO + 정적 팩토리 `from()`. DTO 재사용 금지.
3. **도메인 경계 넘는 JPA 연관관계 금지** — 다른 도메인은 ID로 참조하고 "ID 수집 → in절 일괄 조회 → 조립"(N+1 금지).
4. **적용된 Flyway 마이그레이션은 절대 수정 금지** — 변경은 항상 더 높은 버전의 새 파일로. (수정하면 체크섬 불일치로 기동 실패.)

새 API는 `notice/` 패키지를 통째로 복제해 시작한다(테스트 4종 포함).

---

## 더 읽을거리

- [`server/CLAUDE.md`](../server/CLAUDE.md) — 서버 규칙 인덱스(정본)
- [`docs/api-standard.md`](./api-standard.md) · [`docs/error-spec.md`](./error-spec.md) — **FE 계약**(응답 envelope·에러 코드 체계)
- [`server/docs/local-development.md`](../server/docs/local-development.md) — 로컬 실행 절차 정본
- [`server/docs/backend-development-guide.md`](../server/docs/backend-development-guide.md) · [`server/docs/testing-guide.md`](../server/docs/testing-guide.md) — 구현 흐름·테스트 기준
