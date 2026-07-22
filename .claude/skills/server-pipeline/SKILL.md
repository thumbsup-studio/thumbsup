---
name: server-pipeline
description: "GitHub 이슈 기반 server 작업 파이프라인 (thumbsup 전용, 팀 공유 스킬). 이슈 확보→맥락 수집→계획(1회 확인)→ATDD/TDD 구현→게이트→동적 검증→리뷰→PR→최종 보고까지 무정지 자동 진행. 트리거: 'server 작업 시작', '파이프라인', '/server-pipeline 43', 이슈 번호/URL(https://github.com/thumbsup-studio/thumbsup/issues/NN)을 주며 server 작업을 시작할 때, '43번 이슈 작업해' 같은 표현. app/ 전용 작업에는 사용하지 않는다."
---

# Server 작업 파이프라인 (Thumbs Up)

GitHub 이슈 하나를 받아 **브랜치 생성부터 PR·최종 보고까지 무정지로 자동 진행**하는 오케스트레이터.
각 단계의 실제 규칙은 기존 skill/문서에 위임한다 — 이 파일은 순서와 게이트만 정의하고 규칙을 중복 기술하지 않는다.

## 전역 규칙 (모든 단계에 적용)

- **유일한 확인 지점은 4단계(계획 확정) 한 번뿐.** 그 외에는 사용자에게 묻지 않고 진행하되, 스스로 내린 판단은 근거와 함께 최종 보고에 기록한다.
- **모든 산출물(계획·PR·보고·테스트 DisplayName)은 한국어.**
- **커밋/PR에 Co-Authored-By 등 AI 시그니처 절대 금지.**
- **머지는 사람이 결정** — 자동 머지 금지. 이슈 close는 PR의 `Closes #NN`으로 머지 시 자동 처리되므로 직접 close하지 않는다.
- **시크릿(AWS 키, SSM 값, Swagger 비밀번호) 을 커밋·PR 본문·이슈 코멘트에 노출 금지.** PR에 curl 예시를 넣을 때 인증 정보는 `-u <swagger계정>` 으로 마스킹.
- **Over-engineering 금지** — 이슈의 인수 기준(Acceptance)에 없는 기능·추상화를 추가하지 않는다.
- **서브에이전트 적극 활용** — 탐색·조사·대규모 구현·리뷰를 서브에이전트에 위임하고, 병렬 가능한 조사는 병렬로 돌린다. **리뷰는 구현과 분리된 별도 패스로**(자기 승인 금지), 강한 모델로 수행한다. **특정 에이전트 확장(OMC 등)에 의존하지 않는다** — 전용 에이전트(탐색·코드리뷰 특화)가 있으면 활용하고, 없으면 범용 서브에이전트에 같은 역할을 프롬프트로 지정한다.
- 이 스킬은 레포에 커밋된 **팀 공유 스킬**이다. 수정은 PR로 반영하고, 시크릿(위 규칙)을 파일에 하드코딩하지 않는다 — 인증 값은 SSM에서 읽어 쓴다(7단계 참고).

## 파이프라인 전체 흐름

```text
0. 사전 점검          → 클린 워크트리·main 최신화·Docker
1. 이슈 확보          → assignee 할당, status: in-progress
2. 맥락 수집          → 선행/의존 이슈·관련 코드·규약 문서 (병렬 서브에이전트)
3. 브랜치 생성        → 최신 main에서 분기 · 동명 브랜치 충돌 확인
4. 계획 확정          → ★ 유일한 사용자 확인 지점
5. 구현(Outside-In)   → ATDD red → 단위 TDD 루프 → ATDD green → refactor
6. 정적 게이트        → ./gradlew --no-daemon spotlessApply build
7. 동적 검증          → 로컬 기동 + curl + Swagger 대조 (API 계약 변경 시 필수)
8. 리뷰               → 리뷰 서브에이전트 별도 패스, 수정 루프
9. 문서화             → 정본 문서와의 정합성 확인·갱신
10. 커밋·push·PR      → commit/pr 스킬 준수, 이슈 status: review
11. 최종 보고         → 고정 형식 (아래)
12. FE 공유(필요 시)  → handoff 스킬로 인계 · 백엔드 단독이면 스킵
```

## 단계별 상세

### 0. 사전 점검

```bash
# 더티 워크트리면 즉시 중단 (사용자 미커밋 작업 보호) — 주석이 아니라 실제 게이트
[ -z "$(git status --porcelain)" ] || { echo "워크트리에 미커밋 변경 있음 — 중단하고 사용자에게 보고"; exit 1; }
git checkout main && git pull --ff-only
docker info --format '{{.ServerVersion}}'   # Testcontainers·로컬 기동에 필요. 실패 시 Docker Desktop 실행 안내
```

### 1. 이슈 확보

**입력 파싱:** `43`, `#43`, `https://github.com/thumbsup-studio/thumbsup/issues/43` → 이슈 번호 추출.

**번호 미지정 시:** 후보 목록을 보여주고 선택받는다 (미할당 이슈 우선 정렬):

```bash
gh issue list --repo thumbsup-studio/thumbsup --state open \
  --label "scope: server" --label "status: todo" \
  --json number,title,milestone,assignees,labels
```

**이슈 확보 절차:**

```bash
gh issue view <NN> --repo thumbsup-studio/thumbsup --json number,title,body,labels,assignees,milestone,state
```

- **이슈 `state`가 `OPEN`이 아니면 중단**하고 보고 (닫힌 이슈에 작업하지 않는다).
- **다른 사람이 이미 assignee면 중단**하고 사용자에게 보고 (중복 작업 방지).
- 본인 할당 + 진행 라벨:
  ```bash
  gh issue edit <NN> --add-assignee "@me"
  gh issue edit <NN> --remove-label "status: todo" --add-label "status: in-progress"
  ```

### 2. 맥락 수집 (병렬 서브에이전트)

아래를 **병렬로** 수집한다:

1. **이슈 그래프**: 본문의 `선행/의존: #NN` 이슈들을 `gh issue view`로 읽는다. 선행 이슈가 미완(OPEN + PR 미머지)이면 — 현 이슈를 진행할 수 있는지 판단하고, 불가하면 중단·보고. 해당 이슈를 참조하는 후행 이슈도 검색(`gh search issues`)해 영향 범위를 파악한다.
2. **관련 코드**: 탐색 서브에이전트로 이슈와 관련된 기존 feature·엔티티·마이그레이션을 탐색. 새 feature면 `server/src/main/java/studio/thumbsup/server/notice/`(레퍼런스 feature)와 테스트 4종 구조를 파악한다.
3. **규약 문서**: `server/CLAUDE.md`는 필수. 이슈 성격에 따라 선별 로드 —
   - API 작업: `docs/api-standard.md`, `docs/error-spec.md` (FE 계약 — 어기면 FE가 깨진다)
   - 구현 전반: `server/docs/backend-development-guide.md`
   - 테스트: `server/docs/testing-guide.md`
   - DTO/크로스 도메인 조회: `server/docs/dto-and-query-patterns.md`
   - 에러 처리: `server/docs/error-implementation.md`

### 3. 브랜치 생성

`git fetch origin main`으로 최신을 재확인하고 `origin/main`에서 분기한다. 타입은 이슈의 `type:` 라벨로 결정 (`type: feat`→`feat`, `type: fix`→`fix`, 없으면 `feat`). 동명 브랜치가 로컬·원격에 이미 있으면 진행 중인 타인 작업일 수 있으므로 재사용 여부를 판단하고, 불확실하면 중단·보고한다.

```bash
git fetch origin main
git switch -c <type>/<이슈번호>-<짧은-영문-슬러그> origin/main   # 예: feat/43-insight-api
```

### 4. 계획 확정 ★ 유일한 확인 지점

이슈의 인수 기준을 기반으로 계획을 세우고 **한 번만** 사용자 확인을 받는다. 계획에 포함할 것:

1. **인수 기준 → 테스트 시나리오 매핑** — 인수(통합) 테스트로 갈 핵심 시나리오(정상 흐름 + 비즈니스 규칙 에러)와, 단위·계약 테스트로 내려보낼 세부 분기(validation 변형, 정책 조합, 계산)를 **층으로 나눠** 계획한다 (배분 기준: [references/test-strategy.md](references/test-strategy.md))
2. **API 설계**: 엔드포인트·요청/응답 DTO(record)·에러 케이스(`{Domain}ErrorType`)
3. **Flyway 변경안**: 새 마이그레이션 파일 여부·테이블/컬럼 설계
4. **변경 대상 파일 목록**과 기존 코드에 미치는 영향(회귀 위험)
5. **모호점**: 인수 기준이 여러 해석이 가능하거나 선행 이슈와 충돌하면 **이 시점에 모아서 질문**한다. 이후 단계에서는 질문하지 않는다.

승인받으면 이후 11단계까지 무정지로 진행한다.

### 5. 구현 — Outside-In 이중 루프 (ATDD × TDD)

테스트 **배분 철학**은 [references/test-strategy.md](references/test-strategy.md)(ATDD + 고전파 TDD + Outside-In), **층 정의·도구**는 `server/docs/testing-guide.md`가 정본이다.
핵심 원리: 인수(통합) 테스트는 "기능이 요구사항을 만족하는가"를, 단위 테스트는 "내부 규칙이 정확한가"를 묻는다. **같은 것을 두 층에서 중복 검증하지 않는다.**

**바깥 루프 — ATDD red:** 인수 기준을 핵심 시나리오로 옮긴 인수(통합) 테스트를 먼저 작성해 실패를 확인한다.

- 핵심 시나리오 = 정상 흐름 + **비즈니스 규칙 수준의 에러**(중복, 권한 없음, 상태 충돌 등). 개수를 고정하지 않는다 — 포함 기준은 "이 시나리오가 깨지면 기능이 인수 기준을 만족하지 못하는가".
- 입력 validation 에러는 배선(HTTP status + error code envelope)만 한두 시나리오로 확인하면 충분하고, Controller 계약 테스트가 커버하면 인수 층에서는 생략해도 된다. **변형·조합(길이·형식·경계값 하나하나)을 인수 테스트로 만들지 않는다** — 무거운 층의 조합 폭발은 게이트를 느리게 하고 리팩토링마다 깨지는 테스트를 양산한다. 그 폭발은 안쪽 루프로 내려보낸다.

**안쪽 루프 — 단위 TDD (red→green→refactor 반복):** 각 시나리오를 green으로 만드는 데 필요한 내부 규칙을 촘촘히 검증한다. 배치 기준:

- 도메인 규칙·계산·정책·상태 전이 → **순수 단위 테스트** (Spring 없음)
- DTO bean validation·envelope·에러 코드 → **standalone MockMvc Controller 계약 테스트** (Spring 부팅 없이 변형을 싸게 전수 검증 — validation 폭발은 여기서 흡수)
- JPA 쿼리·스키마 정합 → `@DataJpaTest` + Testcontainers
- **Mock은 외부 시스템 경계에서만** (메일·외부 API 등). DB는 repository 인터페이스가 그 경계이므로 Service 단위 테스트에서 repository stub은 허용(레포 관례 — notice 테스트 4종). 내부 협력 객체 mock 남용 금지 — 상호작용 검증에 묶인 테스트는 리팩토링에 같이 깨진다.

**구현 규칙 (green 과정에서):**
- 새 API는 `server/CLAUDE.md`의 "새 API 만드는 절차"를 따른다 (notice 복제 → 도메인 치환 → 테스트 4종 복제).
- Flyway: `V$(date +%Y%m%d%H%M%S)__설명.sql`. **적용된 파일은 절대 수정하지 않는다.**
- 핵심 규칙 준수: `BusinessException(ErrorType)`만, API별 record DTO + `from()`, 도메인 경계 넘는 연관관계 금지(ID 참조 + in절 일괄 조회), 생성자 주입만, `Clock` 주입, `@Value` default 금지.
- Swagger 어노테이션(`@Operation`, `@Schema` 등)을 구현과 함께 작성한다 — 명세는 8단계 리뷰에서 대조 검증된다.
- `@Nested`/`@DisplayName` 한국어 문장, 메서드명은 ASCII snake_case.

**수렴:** 인수 테스트 green 확인 → 리팩토링(전 층 green 유지). 구현 중 발견한 엣지 케이스는 **알맞은 층에** 보강한다. 인수가 통과해도 단위 테스트를 생략하지 않는다 — 세부 규칙의 회귀는 단위가 지킨다.

### 6. 정적 게이트

```bash
cd server && ./gradlew --no-daemon spotlessApply build
```

테스트·ArchUnit·Spotless·Checkstyle 전부 포함. **통과 전 PR 금지.** 실패하면 수정 후 재실행 루프 (스스로 해결 불가 시에만 중단·보고).

### 7. 동적 검증 (API 계약 변경 시 필수)

**수행 조건** — 다음 중 하나라도 해당하면 필수:
- 엔드포인트 추가/변경, 요청·응답 형식 변경, 에러 응답 변경
- Flyway 마이그레이션 추가

내부 리팩토링만이면 스킵 가능하되 **사유를 최종 보고에 명시**한다.

**절차** — 로컬 기동은 `thumbsup-local-server` 스킬을 그대로 따른다 (AWS profile `thumbsup`, Docker MySQL, `./gradlew bootRun` 백그라운드 실행):

1. health: 2xx만으로 부족하고 응답 **본문의 `status`가 `UP`인지**까지 확인한다.
   ```bash
   curl -fsS http://localhost:8080/actuator/health | grep -q '"status":"UP"' || { echo "health UP 아님"; exit 1; }
   ```
2. **계획서의 시나리오를 curl로 실행** — 정상 케이스 + 에러 케이스(4xx의 error code까지) 응답을 계획과 대조.
3. **Swagger 명세 대조**: 인증 정보는 하드코딩하지 않고 **로컬 SSM에서 읽어 셸 변수로만** 쓴다(profile `thumbsup`). 값을 출력하지 않는다.
   ```bash
   SWAGGER_USER=$(aws ssm get-parameter --name /thumbsup/local/SWAGGER_USERNAME --with-decryption \
     --profile thumbsup --region ap-northeast-2 --query Parameter.Value --output text)
   SWAGGER_PASS=$(aws ssm get-parameter --name /thumbsup/local/SWAGGER_PASSWORD --with-decryption \
     --profile thumbsup --region ap-northeast-2 --query Parameter.Value --output text)
   printf 'user = "%s:%s"\n' "$SWAGGER_USER" "$SWAGGER_PASS" | curl -fsS -K - http://localhost:8080/v3/api-docs
   ```
   구현된 API가 명세에 정확히 반영됐는지 확인: 경로·메서드·요청/응답 스키마·에러 응답·필드 설명(한국어). 불일치 시 어노테이션 수정 → 6단계부터 재실행.
   (자격증명은 SSM에서만 읽고 셸 변수로만 쓴다. `curl -u` 인자로 넘기면 `ps`에 노출되므로 위처럼 stdin config(`-K -`)로 전달한다 — `echo "$SWAGGER_PASS"` 금지, 채팅 로그·커밋·PR·터미널에 값 노출 금지. SSM 접근이 안 되면 `thumbsup-local-server` 스킬의 AWS 프로파일 점검을 따른다.)
4. 종료: `bootRun` 프로세스 종료 후 `cd server && docker compose down`

### 8. 리뷰 (별도 패스 — 자기 승인 금지)

리뷰 서브에이전트(강한 모델)에 diff 전체를 위임한다. 리뷰 관점을 프롬프트에 명시:

1. `server/CLAUDE.md` 핵심 규칙 위반 여부
2. `docs/api-standard.md`·`docs/error-spec.md` FE 계약 위반 여부
3. **Swagger 명세 정확성** (7단계 대조 결과 포함 전달)
4. **회귀 위험**: 기존 동작·기존 테스트·선행/후행 이슈에 미치는 영향
5. 테스트 적정성 — 인수 기준 커버 여부와 **층 배분**(인수 층에 validation 조합 폭발이 없는지, 세부 규칙이 단위·계약 층에서 커버되는지, 같은 검증의 층간 중복이 없는지)

- Critical/Major 지적 → 수정 후 6단계(게이트)부터 재실행, 재리뷰. **최대 3회 루프**, 초과 시 중단하고 사용자에게 보고.
- 인증/인가·입력 처리·시크릿을 건드린 경우 보안 리뷰 서브에이전트를 추가로 병렬 실행.

### 9. 문서화

- 이번 변경이 정본 문서(`docs/api-standard.md`, `docs/error-spec.md`, `server/docs/*`)와 어긋나는 새 패턴을 도입했다면: 문서를 갱신하거나 코드를 문서에 맞춘다 (원칙: 코드를 문서에 맞추는 쪽 우선).
- 크로스 도메인 조회 등 "첫 사례"가 되는 구현이면 해당 문서에 예시 반영을 검토한다.
- 문서 변경도 같은 브랜치·같은 PR에 포함한다.

### 10. 커밋 · push · PR

1. **커밋**: `commit` 스킬 형식 그대로 (`<type>(server): <한국어 요약> (#NN)`). 관심사별 분리 커밋. **시그니처 금지.**
2. **push**: `git push -u origin <branch>`
3. **PR 생성**: `pr` 스킬의 템플릿을 기반으로 하되, 리뷰·회귀 방지·선/후행 파악에 필요한 정보를 추가한다:

```markdown
## 무엇을 / 왜
<이슈 요약과 이 PR의 접근 방식>

## 변경 사항
- <구현 내용, Flyway 마이그레이션 포함>

## 선행 / 후행
- 선행: #NN (<상태와 이 PR과의 관계>)
- 후행 영향: <이 PR이 열어주는/막는 작업, 없으면 "없음">

## API 계약
- <추가/변경된 엔드포인트 요약. 없으면 "변경 없음">
- <curl 요청/응답 예시 — 인증 정보 마스킹>

## 회귀 영향
- <기존 동작에 미치는 영향과 그렇게 판단한 근거. 없으면 "없음 — 근거">

## DB 변경
- <Flyway 파일명과 DDL 요약. 없으면 "없음">

## 테스트 증거
- `./gradlew build` 통과 (테스트 NN개)
- <인수 테스트 시나리오 목록>
- <동적 검증(curl) 수행 여부와 결과, 스킵했으면 사유>

## 관련 이슈
Closes #NN

## 체크리스트
- [ ] 제목이 커밋 컨벤션을 따른다
- [ ] 로컬에서 동작 확인
- [ ] 하나의 관심사만 담았다
```

4. **이슈 라벨 갱신**: `gh issue edit <NN> --remove-label "status: in-progress" --add-label "status: review"`
5. PR URL을 사용자에게 보여준다. **머지하지 않는다.**

### 11. 최종 보고 (고정 형식)

```markdown
## 핵심 정리
<무엇을 만들었고 어떻게 동작하는지 3~5줄>

## PR
<URL>

## 인수 기준 충족
- [x] <기준> — <검증 방법(테스트명/curl)>

## DB 변경
<Flyway 파일·DDL 요약, 배포 시 자동 적용 여부. 없으면 "없음">

## 인프라 / 운영 확인 필요
<SSM 파라미터 추가, 보안그룹, 환경변수 등. 없으면 "없음">

## 스스로 판단한 사항
<질문 없이 진행하며 내린 판단과 근거, 스킵한 단계와 사유>

## 후속 작업 제안
<이 이슈에서 파생됐지만 범위 밖인 작업, 후행 이슈에 전달할 정보>
```

### 12. FE 공유 (필요 시 — handoff 스킬)

이 작업이 FE에 영향을 준다면 — 엔드포인트 추가/변경, 요청·응답 형식 변경, breaking change 등 FE가 알아야 할 것 — **`handoff` 스킬로 인계한다.** 메신저 문구·정본 형식은 그 스킬이 정의하므로 여기서 중복 기술하지 않는다.

백엔드 단독 변경(FE가 알 필요 없는 내부 리팩토링·로직)이면 이 단계는 **스킵**하고, 스킵 사유를 최종 보고에 한 줄로 남긴다.

## 실패 처리

- 어느 단계든 **스스로 해결 시도**가 우선. 해결 불가로 판단되면 그 시점까지의 상태(브랜치·커밋·이슈 라벨)를 정리해 보고하고 중단한다.
- 중단 시 이슈 라벨은 `status: in-progress`로 남겨 다른 사람의 중복 착수를 막는다 (보고에 명시).
- 파이프라인 재개 요청(예: "이어서 해") 시 대화 맥락에서 마지막 완료 단계를 파악해 그 다음부터 진행한다.
