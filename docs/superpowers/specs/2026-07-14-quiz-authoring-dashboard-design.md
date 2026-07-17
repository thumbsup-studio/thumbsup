# 문제 저작 대시보드 (생성·검수·개선) — 설계

- **날짜**: 2026-07-14
- **상태**: Draft (사용자 리뷰 대기)
- **관련 코드**: `server/src/main/java/studio/thumbsup/server/quiz/generation/*`, `.claude/skills/quiz-generation`
- **관련 스킬**: `quiz-generation`, `elice-models`, `frontend-api`

---

## 1. 배경 & 문제

지금 문제(퀴즈) 생성은 **서버가 Elice API(OpenAI 호환 프록시)를 호출하는 CLI 전용 파이프라인**(`generate` 프로파일, #26)이다. 비용·권한 문제로 상시 HTTP 엔드포인트로 열지 않았고, 프로덕션 반영은 "로컬 생성 → 수동 검수 → SQL 마이그레이션"이라는 수작업 단계를 거친다.

원하는 것은 이와 **근본적으로 다른 접근**이다:

- 팀원 각자가 **자기 개인 AI CLI 구독**(claude-code / codex / gemini CLI)으로 문제를 생성·검수·개선한다. 공용 API 키로 토큰당 과금하는 대신, 이미 각자 쓰는 구독을 활용해 **공용 비용 0**을 목표로 한다.
- **웹 대시보드**에서 버튼 한 번으로 생성/검수/개선을 트리거하고, 진행 상황을 웹 터미널로 실시간으로 본다.
- 문제는 `draft → approved` 라이프사이클을 가지며, **여러 팀원의 여러 번 검수**로 품질을 다듬은 뒤 사람이 명시적으로 승인한다.

## 2. 목표 / 비목표

**목표**
- 웹 대시보드에서 원클릭으로 문제 **생성 / 검수 / 개선**을 트리거.
- 실제 AI 실행은 **각 팀원 로컬 머신에서 개인 구독으로** 이뤄진다 (공용 API 키 미사용).
- `draft → approved` 상태 관리, 검수 라운드 이력(revision) 누적, 사람의 명시적 승인.
- 승인 시 실제 `quiz` 테이블로 반영 → 기존 수동 SQL 마이그레이션 단계를 대체.
- 이미 등록된(라이브) 문제를 **개별 문제 단위로 개선**.

**비목표 (이번 범위 밖)**
- 세밀한 권한/역할(admin/reviewer) 분리 — 인증된 팀원이면 모두 가능(후속).
- 인터랙티브 터미널(사람이 직접 프롬프트 타이핑) — 원클릭 자동 실행만.
- 브리지를 데스크톱 앱(tray)으로 패키징 — MVP는 CLI(`npx`)로 실행.
- 라이브 문제 콘텐츠 버저닝(과거 학습 이력과의 정합성) — 개선은 in-place 갱신, 정합성 이슈는 flag만.

## 3. 핵심 결정 요약

| # | 결정 | 근거 |
|---|---|---|
| D1 | **CLI는 각 팀원 로컬 머신에서 실행** | 개인 구독은 디바이스에 로그인된 CLI에 묶임. 서버 실행 불가·ToS. 공용 비용 0 |
| D2 | **연결 = 서버 코디네이션** (브라우저·브리지 모두 AWS 서버만 바라봄) | Vercel 서버리스+NAT 제약 회피, 배포 친화적, 새 인프라 0 |
| D3 | **원클릭 자동 실행** (고정 프롬프트·고정 출력 포맷) | 품질은 다중 검수로 수렴. 터미널은 진행 로그 뷰어(사람이 타이핑 X) |
| D4 | **승인 = 사람의 명시적 액션** | 검수 = AI 비평+수정 1회 라운드(revision 누적), 승인은 별도 사람 판단 |
| D5 | **개선 = 개별 문제 단위, 승인 시 in-place UPDATE** | "이 문제 하나 이상해" 니즈. 퀴즈 ID 보존 → 사용자 진행·이력 FK 유지 |
| D6 | **승인 = 즉시 라이브 반영** | 수동 SQL 마이그레이션 대체, MVP 단순화 |
| D7 | **브리지는 CLI를 직접 exec** (Claude는 Agent SDK 금지) | Agent SDK는 `ANTHROPIC_API_KEY` 강제 → 구독 전제 파괴. `claude -p`만 구독 과금 |
| D8 | **잡 큐 = MySQL 테이블 + 폴링** (Temporal/DBOS 미도입) | 3인 규모엔 과함. DBOS는 Postgres 전용(서버는 MySQL 8.4) |

## 4. 시스템 아키텍처

세 레이어와, 그것들을 잇는 **두 개의 비동기 채널**. 브라우저와 브리지는 서로를 모르고, **둘 다 AWS 서버만** 바라본다.

```
┌─────────────────────┐         ┌──────────────────────────────┐        ┌────────────────────────┐
│  웹 대시보드 (Vercel)  │         │        AWS 서버 (Spring)         │        │  로컬 브리지 (팀원 노트북)  │
│                     │         │                              │        │                        │
│  · 문제 목록/상태     │──HTTPS─▶│  잡 큐  +  draft 저장소          │◀─폴링──│  ① 잡 받기               │
│  · 생성/검수/개선/승인 │  REST   │  +  로그 버퍼                    │  아웃  │  ② claude/codex/gemini  │
│  · 터미널 뷰어(xterm) │◀─SSE───│                              │  바운드 │     헤드리스 exec          │
│                     │  로그    │  (CLI 실행 안 함, 조율만)         │──POST─▶│  ③ 로그 append          │
└─────────────────────┘  스트림  └──────────────────────────────┘  결과   │  ④ 결과 JSON export      │
                                                                        └────────────────────────┘
```

**채널 1 — 브리지 ↔ 서버 (아웃바운드 폴링):**
- `GET /bridge/jobs/next` (롱폴): 자기 소유 잡을 가져가 `RUNNING` 표시
- `POST /bridge/jobs/{id}/logs`: 실행 중 로그 라인 append
- `POST /bridge/jobs/{id}/result` / `/fail`: 완료 결과 or 실패
- 전부 브리지가 **바깥으로** 거는 요청 → NAT·방화벽 무관.

**채널 2 — 브라우저 ↔ 서버 (SSE):**
- `GET /jobs/{id}/stream` (Server-Sent Events): 로그를 거의 실시간으로 터미널 뷰에 그림.
- 나머지(목록·액션·승인)는 평범한 REST.

**핵심 불변식:** CLI를 실제로 실행하는 주체는 **오직 브리지**. 웹과 서버는 지시·저장·중계만.

**"시작한 사람이 실행자다":** 잡의 `assignee = 클릭한 사람`. 브리지는 **자기 소유 잡만** 폴링해서 가져간다. 그래야 "각자 자기 구독으로"가 성립 — 생성 클릭한 사람의 노트북이 생성하고, 검수 클릭한 사람의 노트북이 검수한다.

**배치 (모노레포):**
- `app/` — 대시보드는 기존 Next.js 앱의 **보호된 라우트 그룹**(예: `app/(authoring)/`)으로 MVP. Vercel·인증 인프라 재사용. (분리 여부는 §12 미해결)
- `server/` — 잡 큐·draft 저장·SSE는 Spring에 추가. 기존 `quiz/generation` 검증 로직 재사용.
- `bridge/` — 신규 top-level Node/TS 패키지 (`npx thumbsup-bridge`).

## 5. 데이터 모델

**중요 판단: draft를 기존 `quiz` 테이블에 섞지 않고 별도 스테이징 테이블에 둔다.** 학습 앱이 `quiz`를 status 필터 없이 읽기 때문 — 미검수 draft가 학습자에게 새는 것을 원천 차단하고, 프로덕션 읽기 경로를 한 줄도 안 건드린다. 승인 시점에만 `quiz`로 승격(materialize)한다.

```
generation_job        ── 브리지가 집어가는 작업 단위
  id            PK
  kind          GENERATE | REVIEW          -- 개선의 첫 패스도 "지시 담긴 REVIEW"
  status        QUEUED | RUNNING | SUCCEEDED | FAILED
  assignee      userId                     -- 클릭한 사람 = 실행자
  cli           CLAUDE | CODEX | GEMINI NULL -- 브리지가 pickup 시 기록 (감사·비용용)
  payload       JSON  { topic } | { draftId, feedback?, instruction? }
  prompt        TEXT                        -- 서버가 잡 생성 시 렌더한 완성 프롬프트 (브리지는 실행만)
  outputSchema  JSON                        -- CLI에 넘길 스키마
  error         TEXT NULL
  createdAt, startedAt, finishedAt

quiz_draft            ── 검수 대상 (신규=스텝5, 개선=문제1)
  id            PK
  origin        NEW | IMPROVE
  scope         STEP | SINGLE               -- NEW=STEP(5), IMPROVE=SINGLE(1)
  status        DRAFT | APPROVED
  topic         VARCHAR
  sourceQuizId  FK quiz.id NULL             -- IMPROVE일 때 대상 라이브 문제
  currentPayload JSON                       -- 최신 내용 (5문제 또는 1문제)
  createdBy, approvedBy NULL, approvedAt NULL
  createdAt, updatedAt

quiz_draft_revision   ── 검수 라운드마다 누적
  id            PK
  draftId       FK quiz_draft.id
  revisionNo    INT
  payload       JSON                        -- 그 시점 내용 스냅샷
  reviewSummary TEXT                        -- AI가 무엇을 바꿨는지
  reviewedBy    userId
  jobId         FK generation_job.id
  createdAt

job_log               ── 스트리밍용 append-only
  id            PK
  jobId         FK generation_job.id
  seq           INT
  line          TEXT
  createdAt
```

## 6. 상태 머신

```
[생성 클릭]  (topic 입력)
   └─▶ generation_job(GENERATE) ─브리지 실행─▶ quiz_draft(origin=NEW, scope=STEP, DRAFT, rev1)

[검수 클릭]  (여러 번, 여러 팀원 / feedback? 선택)
   └─▶ generation_job(REVIEW, draftId) ─브리지 실행─▶ currentPayload 갱신
                                                    + quiz_draft_revision rev N+1
       (status는 계속 DRAFT)

[개선 클릭]  (라이브 문제에서, instruction 입력)
   └─▶ quiz_draft(origin=IMPROVE, scope=SINGLE, sourceQuizId, DRAFT, currentPayload=원본 복제)
       └─▶ generation_job(REVIEW, instruction) ─▶ 검수 라운드와 동일

[승인 클릭]  (사람 판단)
   └─▶ quiz_draft.status = APPROVED  (즉시)
       ├─ origin=NEW    → quiz 테이블에 스텝 신규 INSERT (기존 QuizPersister 재사용)
       └─ origin=IMPROVE → sourceQuizId 행을 in-place UPDATE (퀴즈 ID 보존)
```

- 개선 중에도 원본은 라이브 유지, **승인 순간에만** 되쓰기.
- 개선 프롬프트에는 대상의 형제 문제(같은 스텝 나머지 4개)를 **읽기 전용 맥락**으로 넣어 중복 개념·난이도 균형을 맞춘다. 대상 문제의 `type`·`difficulty`·`slotOrder`는 고정(내용만 개선).

## 7. REST API

CLI는 대시보드가 지정하지 않는다 — **팀원의 브리지가 자기 설정 CLI로 실행**하고, 서버는 pickup 시점에 어떤 CLI였는지만 기록한다(감사·비용).

**대시보드용 (팀원 JWT 인증)**
```
POST /drafts/generate        { topic }               → GENERATE 잡 생성, { jobId }
POST /quizzes/{id}/improve    { instruction }         → quiz_draft(IMPROVE) 복제 + REVIEW 잡 → { draftId, jobId }
POST /drafts/{id}/review      { feedback? }           → REVIEW 잡 생성 → { jobId }
POST /drafts/{id}/approve                             → status=APPROVED + 즉시 materialize
GET  /drafts?status=DRAFT                             → draft 목록
GET  /drafts/{id}                                     → 상세(revision 이력 포함)
GET  /quizzes                                         → 라이브 문제 목록 (개선 진입점)
GET  /jobs/{id}                                       → 잡 상태
GET  /jobs/{id}/stream        (SSE)                   → 로그 실시간 스트림
```

**브리지용 (팀원 토큰 인증 — 자기 잡만)**
```
GET  /bridge/jobs/next              (롱폴)  → 내 QUEUED 잡 1개 → RUNNING, { prompt, outputSchema, payload } 반환
POST /bridge/jobs/{id}/logs         { lines[] }          → job_log append → SSE 팬아웃
POST /bridge/jobs/{id}/result       { payload, cli }     → 서버 검증 후 적용 (아래), cli 기록
POST /bridge/jobs/{id}/fail         { error }            → FAILED
```

**result 적용 분기 (서버가 authoritative):**
- `GENERATE` → `quiz_draft(NEW)` 생성, rev1
- `REVIEW` → `currentPayload` 갱신 + `quiz_draft_revision` rev N+1 누적

## 8. 브리지 상세

**본질:** 팀원 노트북에서 도는 작은 Node/TS 실행기(~200–300줄). 브라우저 샌드박스가 로컬 프로세스를 spawn 할 수 없기 때문에 **네이티브 실행 주체로서 반드시 존재**한다. 24시간 상주가 아니라 **작업할 때만** 켠다(`pnpm dev` 감각).

**메인 루프:**
```ts
loop:
  job = await longPoll(GET /bridge/jobs/next)              // 내 잡. job.prompt = 서버가 렌더한 완성 프롬프트
  adapter = { CLAUDE, CODEX, GEMINI }[MY_CLI]              // MY_CLI = 브리지 config
  finalJson = await adapter.run(job.prompt, job.outputSchema, { onLog: line => POST .../logs })
  POST .../result { payload: finalJson, cli: MY_CLI }       // 검증 실패 시 서버가 fail 처리
  // 예외 → POST .../fail { error }
```

**설계 결정 D7 상세 — 프롬프트는 서버가 렌더링, 브리지는 멍청한 실행기.**
프롬프트 로직을 서버 한 곳(기존 `QuizGenerationPromptBuilder` 재사용)에 두면 프롬프트 수정에 **브리지 재배포가 불필요**하고, 팀원마다 다른 프롬프트가 도는 사고를 막는다. 브리지는 "이 프롬프트를 내 CLI로 돌려 결과 JSON을 돌려줘"만 안다.

**프로세스 스포닝:** `execa` 기본, `node-pty`는 폴백.
- 우리는 TTY 진행 UI가 아니라 **헤드리스 JSON**을 원하므로 stdout 파이프(`execa`)로 충분. 대부분의 에이전트 CLI는 non-TTY를 감지하면 헤드리스로 전환한다.
- 특정 CLI가 TTY 없이 오작동하면 그때만 `node-pty`로 가짜 터미널 할당.

**CLI 어댑터 (구독 세션 + 헤드리스 + 스키마 강제 JSON):**

| CLI | 1회 로그인 (팀원 머신) | 브리지 exec |
|---|---|---|
| Claude | `claude setup-token` → `CLAUDE_CODE_OAUTH_TOKEN` (1년) | `claude -p "<prompt>" --output-format json --json-schema '<schema>'` |
| Codex | `codex login --device-auth` | `codex exec --json --output-schema <file> "<prompt>"` |
| Gemini | `gemini` (Google 로그인) | `gemini -p "<prompt>" --output-format json` |

**출력 추출 (가장 튼튼한 방식):** 프롬프트에서 "최종 결과를 `./.thumbsup/out.json`에 써라"고 지시하고 브리지가 그 파일을 읽는다. CLI별 JSON 봉투 차이(claude `.result` / gemini `.response` / codex JSONL)를 무시할 수 있다. `--json-schema`/`--output-schema`는 CLI 레벨에서 스키마 위반을 걸러 서버 검증 실패율을 낮춘다.

**⚠️ 구독 유지 규칙 (전제 보호):**
- **API 키 환경변수 주입 금지.** 특히 Codex는 API 키가 있으면 구독이 아니라 API 과금으로 샌다. 브리지는 캐시된 OAuth 세션만 쓰게 한다.
- **Claude `--bare` 모드 금지.** bare는 `CLAUDE_CODE_OAUTH_TOKEN`을 안 읽고 API 키를 요구한다.
- **Claude Agent SDK 금지.** `ANTHROPIC_API_KEY` 강제 → 구독 과금 불가.
- 비용 가시성: `--output-format json` 결과의 `total_cost_usd`를 잡에 로깅 → 팀원별 사용량 추적.

## 9. 프롬프트 / 출력 계약

- **출력 스키마는 기존 `GeneratedQuizSet` 재사용.** 생성=5문제(고정 슬롯: OX/OX/객관식/객관식/키워드빈칸), 개선=대상 유형·난이도·슬롯 유지한 1문제.
- **서버가 렌더**: `QuizGenerationPromptBuilder`가 topic/기존문제/개선지시를 받아 완성 프롬프트 + 스키마를 잡에 실어 보냄.
- **검증은 서버가 최종 판정**: result 수신 시 기존 검증기(`CodeSnippetValidator`·`KeywordMarkerValidator`·슬롯 정합성) 그대로. 브리지 결과는 신뢰하지 않는다. 실패 시 사유가 터미널에 표시되고 잡은 FAILED.

## 10. 에러 처리 / 동시성 / 인증

**인증**
- 대시보드: 기존 팀 로그인(JWT). MVP는 인증된 팀원이면 생성·검수·개선·승인 모두 가능(역할 분리는 후속 flag — 코드베이스에 admin/role 체계 없음).
- 브리지: 팀원 토큰을 config에 저장해 폴링·POST 시 사용 → 서버가 잡을 그 사람에 묶음.

**동시성**
- draft 하나에 **활성 잡 1개만**. RUNNING인 draft에 두 번째 검수/승인 오면 409.
- 개선은 **같은 `sourceQuizId`에 열린 draft 1개만** 허용(두 사람 동시 개선 방지).
- revision은 `revisionNo`로 낙관적 정합성 체크.

**에러**
- CLI 실패/타임아웃 → 브리지가 fail → 터미널에 에러, 사람이 재실행.
- 브리지 꺼져 있으면 → 잡 QUEUED 유지, 대시보드에 "브리지 대기 중 — 브리지를 켜세요" 표시, N분 후 만료.
- 모델 JSON 불량 → 서버 검증 거부 → FAILED(사유 포함).
- 실행 중 로그 heartbeat 끊기면 → stale 처리 후 재실행 허용.

## 11. 기술 선택 & 근거 (리서치 요약)

**핵심 재구성:** 이 시스템에서 우리는 **에이전트를 만들지 않는다 — 에이전트는 각 팀원의 CLI 그 자체.** 따라서 LangGraph·Vercel AI SDK·Mastra 같은 "에이전트 저작 프레임워크"는 **틀린 레이어**다(API 키로 에이전트 루프를 직접 짠다고 가정). 필요한 것은 얇은 세 레이어뿐.

| 레이어 | 채택 | 배제 & 이유 |
|---|---|---|
| CLI 실행 | `execa` (+폴백 `node-pty`), 프롬프트→`out.json` 파일 추출, CLI별 스키마 플래그 | Claude Agent SDK — API 키 강제로 구독 전제 파괴 |
| 잡 큐 | MySQL `generation_job` + Spring `@Scheduled` 폴링 (또는 `yoomoney/db-queue`) | Temporal — 3인 규모 과함 / DBOS — Postgres 전용, 서버는 MySQL 8.4 |
| 스트림+터미널 | Spring `SseEmitter` → `EventSource` → `@xterm/xterm` + `react-xtermjs` | `@xterm/addon-attach` — 단방향 SSE라 불필요 |

- 세 CLI 모두 **캐시된 OAuth 로그인을 헤드리스 실행이 재사용** → 개인 구독으로 자동 실행 가능(검증 완료).
- 기존 멀티-CLI 오케스트레이터(Sage/Emdash/Claude Squad 등)는 전부 "git worktree 병렬 코딩" 도구라 우리 형태와 다름 — 브리지는 직접 만들되, 그들의 **CLI 어댑터 추상화는 참고** 가능. **ACP(Agent Client Protocol)** 성숙도는 조사 대상(§12).
- xterm.js는 CLI가 뿜는 ANSI 색상/이스케이프를 제대로 렌더 → "웹에서 터미널이 열린다" 경험 성립.

## 12. 테스팅 전략

- **서버**: 잡 상태 전이, draft 라이프사이클, materialize(NEW 삽입 / IMPROVE in-place UPDATE), 검증 재사용 — 유닛 + 기존 `*AcceptanceTest` 패턴의 REST 인수테스트.
- **브리지**: 가짜 CLI(정해진 JSON 뱉는 스크립트)로 어댑터·파싱·POST 유닛테스트 + 로컬 서버 상대 통합. `--json-schema` 위반/타임아웃/네트워크 드롭 케이스.
- **대시보드**: 터미널 뷰어(SSE)·목록·액션 컴포넌트 테스트 + 클릭→잡→draft e2e(브리지 스텁).

## 13. 미해결 / 후속 (to confirm & flag)

1. **대시보드 배치**: 기존 `app/`의 보호된 라우트 그룹(MVP 추천) vs 별도 Next.js 앱. 소비자 학습 앱과 인증 표면·번들을 섞는 것의 트레이드오프.
2. **라이브 문제 개선의 콘텐츠 버저닝**: in-place UPDATE로 정답 등을 바꾸면 그 문제를 이미 푼 학습자의 과거 이력과 미묘하게 어긋난다. MVP는 in-place, 정합성 정책은 후속.
3. **역할/권한 분리**: 누가 승인 가능한가. MVP는 전원 가능.
4. **구독 rate limit**: Gemini 무료 OAuth는 60 req/분·1000 req/일. 우리 볼륨엔 충분하나 대량 생성 시 병목 가능. Claude Pro/Max·Codex 헤드리스 동시성 한계는 문서 미상 — 사용량 로깅으로 관찰.
5. **ACP(Agent Client Protocol)** 채택 조사: CLI별 어댑터를 직접 짜는 대신 통일 프로토콜로 대체 가능한지.
6. **Codex API-key 과금 버그**(openai/codex#2000): ChatGPT 로그인인데도 API 키가 생성돼 과금되는 케이스 — 브리지 셋업 시 env 점검 필요.

## 14. 참고

- Codex: [non-interactive mode](https://developers.openai.com/codex/noninteractive), [exec docs](https://github.com/openai/codex/blob/main/docs/exec.md), [auth](https://developers.openai.com/codex/auth)
- Gemini: [headless](https://geminicli.com/docs/cli/headless/), [auth](https://geminicli.com/docs/get-started/authentication/), [quota](https://geminicli.com/docs/resources/quota-and-pricing/)
- Claude: [headless](https://code.claude.com/docs/en/headless.md), [Agent SDK auth](https://code.claude.com/docs/en/authentication.md)
- 내구성 실행: [DBOS vs Temporal](https://www.tiarebalbi.com/en/blog/dbos-vs-temporal-postgres-durable-execution), [Temporal 대안](https://www.zenml.io/blog/temporal-alternatives)
- 터미널: [@xterm/xterm](https://www.npmjs.com/package/@xterm/xterm), [react-xtermjs](https://www.qovery.com/blog/react-xtermjs-a-react-library-to-build-terminals), [node-pty](https://github.com/microsoft/node-pty)
- 오케스트레이터 레퍼런스: [awesome-cli-coding-agents](https://github.com/bradAGI/awesome-cli-coding-agents)
