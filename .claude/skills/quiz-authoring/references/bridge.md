# 브리지 (`bridge/`)

팀원 노트북에서 도는 로컬 실행기. 서버 잡 큐를 폴링해 **각자의 개인 AI CLI 구독**으로 헤드리스 실행하고, 로그를 중계하고, 결과 JSON을 제출한다. 공용 API 키로 토큰당 과금하지 않는 것이 이 구조의 존재 이유다.

브리지는 프롬프트를 조립하지 않는 **멍청한 실행기**다 — 서버가 렌더링해 잡에 실어 보낸다.

**설치·로그인 정본은 [`bridge/README.md`](../../../../bridge/README.md)다.** 여기에 복붙하지 말고 그쪽을 볼 것. 요약하면 `claude setup-token`으로 구독 로그인 → `pnpm start login` → `pnpm start`.

## ⚠️ 잡은 CLI가 아니라 **계정**으로 라우팅된다

이게 "잡이 계속 QUEUED"의 가장 흔한 원인이다.

```sql
-- GenerationJobRepository.pickNextQueued — WHERE에 cli가 없다
WHERE status = 'QUEUED' AND assignee_user_id = :userId
ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED
```

**대시보드에서 생성 버튼을 누른 계정과 브리지가 `pnpm start login`한 계정이 같아야 한다.** 팀원 A의 잡을 팀원 B의 브리지가 대신 소화할 수 없다.

`generation_job.cli` 컬럼으로 진단하지 마라 — 그 값은 **잡이 끝날 때 결과와 함께 사후 기록**된다. QUEUED·RUNNING 잡의 `cli`는 **항상 NULL**이다.

## 폴링은 롱폴이 아니다

서버 `GET /api/v1/authoring/bridge/jobs/next`는 즉시 반환한다(`DeferredResult`도 `SseEmitter`도 없다). 브리지가 **3초 고정 간격**으로 짧은 폴링을 한다(`runner.ts`의 `DEFAULT_POLL_INTERVAL_MS`, 변경 불가).

- 생성 버튼을 눌러도 **최대 3초 + CLI 기동 시간**이 지나야 잡이 잡힌다.
- 잡을 처리한 직후엔 자지 않고 바로 다음 폴링 — 큐가 밀려 있으면 연속 처리한다.
- 네트워크가 끊기거나 노트북을 닫았다 열어도 브리지는 죽지 않는다(예외를 잡고 3초 뒤 재시도). 다만 **백오프가 없어** 계속 3초 간격이다.

브리지 엔드포인트는 전부 `/api/v1/authoring/bridge/**`다. `/bridge/**` 같은 별도 루트는 **없다**.

## 구독 유지 규칙 (어기면 개인 구독 대신 API 과금)

`spawn.ts`의 `sanitizedEnv()`가 자식 프로세스 env에서 아래 **5개**를 제거한다:

```text
ANTHROPIC_API_KEY · OPENAI_API_KEY · GOOGLE_API_KEY
GEMINI_API_KEY · GOOGLE_APPLICATION_CREDENTIALS
```

**`claude --bare`를 절대 쓰지 마라.** "훅·auto-memory·CLAUDE.md 자동탐색 skip"이라 딱 맞아 보이지만 OAuth와 키체인을 읽지 않아 **구독 인증이 깨진다**(`CLAUDE_CODE_OAUTH_TOKEN` 미참조).

⚠️ **이건 허용목록이 아니라 차단목록이다.** 나머지 환경변수는 전부 자식에게 넘어간다 — `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_USE_BEDROCK`, `AWS_*`, `VERTEX_*` 등으로 **여전히 과금이 샐 수 있다.** 셸 프로파일에 이런 걸 전역으로 심어두지 마라.

## 격리 플래그 — 왜 붙어 있나 (제거 금지)

`claude.ts`가 `claude`에 넘기는 **전체 인자**:

```text
-p <프롬프트>
--output-format stream-json   --verbose
--json-schema <서버가 준 스키마>
--tools ""   --strict-mcp-config   --setting-sources ""   --disable-slash-commands
--system-prompt "너는 요청받은 JSON만 출력하는 생성기다."
+ cwd: tmpdir()
```

없으면 **운영자의 개인 환경 전체를 상속한다** — 실측: "1+1" 한 줄에 **45,416 토큰**(툴 30·MCP 10·슬래시 213·훅·프로젝트 CLAUDE.md·**운영자 개인 메모리 인덱스와 이메일**). 붙이면 **616 토큰**.

문제는 비용만이 아니다. **팀원마다 개인 설정이 달라 같은 주제도 생성 결과가 달라진다.**

- `--tools ""`를 줘도 `StructuredOutput`은 남아 `--json-schema` 구조화 출력이 그대로 동작한다.
- `--system-prompt`로 기본 시스템 프롬프트를 덮는 이유: 서버가 이미 `QuizGenerationPromptBuilder.SYSTEM_PROMPT`를 프롬프트 앞에 붙여 보낸다.
- `--model`은 **고정하지 않는다** — 운영자 개인 모델 설정을 존중한다(팀 결정).
- `--max-turns`는 claude CLI에 없는 플래그다. 단발 완성 강제는 `--tools ""`로 한다.

### CLI별 격리 수준 (코드 기준)

| | claude | codex | gemini |
|---|---|---|---|
| API 키 제거(`sanitizedEnv`) | ✅ | ✅ | ✅ |
| `cwd: tmpdir()` | ✅ | ❌ `process.cwd()` | ❌ `process.cwd()` |
| 툴·MCP·설정·슬래시 차단 | ✅ | ❌ | ❌ |
| 시스템 프롬프트 교체 | ✅ | ❌ | ❌ |
| 스키마를 CLI에 강제 | ✅ `--json-schema` | ❌ (의도적 제거) | ❌ (플래그 없음) |
| 중간 로그 스트리밍 | ✅ | ✅ | ❌ (완료까지 무음) |

**codex·gemini는 cwd를 지정하지 않아 `bridge/`에서 실행된다** → 레포 루트의 `AGENTS.md`를 상속한다. codex의 `--output-schema`는 strict 비호환(400)이라 제거됐고, 두 CLI 모두 문제 개수를 프롬프트 지시로만 통제하므로 **5문제 제약이 어긋날 확률이 구조적으로 높다.**

팀 주력은 **claude**다(실기기 검증 완료). codex·gemini는 팀 미구독으로 실측 미검증.

## ⚠️ 진단 함정 — 로그 이벤트를 오해하지 마라

**이 절이 이 문서의 핵심이다.** 과거 세션이 아래를 오해해 "존재하지 않는 버그"를 고치려 했다.

| 증상 | 오해 | 사실 |
|---|---|---|
| `[system]` 이벤트가 수십~수백 개 | "에이전틱 툴 루프에 빠졌다" | 대부분 **`system/thinking_tokens`** — 모델이 사고하는 동안 **약 3초당 1개**씩 나오는 진행 표시. 정상이며 격리로 못 없앤다 |
| `[rate_limit_event]` 출현 | "레이트리밋에 걸려 실패했다" | 페이로드가 **`{"status":"allowed"}`** 인 정기 상태 핑. "1+1"짜리 성공 실행에서도 뜬다 |
| 잡이 몇 분째 RUNNING | "정체됐다" | 5문제(≈25KB JSON) 생성은 **정상적으로 4~6분** 걸린다. 사고 중엔 로그가 멈춘 것처럼 보인다(stream-json은 완성된 메시지 단위로만 이벤트를 낸다) |
| `job_log`에 `[error]` 줄이 있음 | "실패했다" | codex는 `error` 이벤트를 실패로 취급하지 않는다 — 잡은 SUCCEEDED일 수 있다 |

브리지는 이벤트 **타입만** 기록하고 payload는 저장하지 않는다. `job_log`의 `[system]`·`[rate_limit_event]` 줄에 내용이 없는 건 정상이다.

**짧은 프롬프트로 프로브하면 오판한다** — 사고 시간이 없어 `thinking_tokens`가 안 나오고 훅 이벤트만 보인다. 장시간 실행으로 재현할 것.

## ⚠️ 브리지는 조용한데 대시보드는 FAILED

서버가 결과 검증에 실패하면 `/result` 응답은 **HTTP 200 + `{status:"FAILED", error:"..."}`** 다. 브리지는 이 반환값을 쓰지 않고 그냥 "done"으로 넘어간다.

→ **브리지 콘솔에 아무 에러가 없어도 잡은 실패했을 수 있다.** 사유는 `generation_job.error` 컬럼에만 있다.

(`POST /fail`은 CLI 실행 자체가 죽었을 때 전용이다. 서버 검증 실패와 혼동하지 마라.)

## ⚠️ 대시보드를 열어보는 행위가 잡을 죽일 수 있다

브리지에는 **타임아웃이 전혀 없다**(CLI가 매달리면 무한 대기). 반면 서버 `RUNNING` 만료는 **10분**이고, 만료는 **lazy 평가**다 — 조회·가드 시점에만 판정한다.

CLI가 평소보다 느려 10분을 넘겼을 때:
- 아무도 조회하지 않으면 만료가 굳지 않아 늦게라도 `postResult`가 통과한다.
- 그 사이 **누군가 대시보드에서 잡 상태를 열면 그 순간 FAILED로 굳는다** → 이후 브리지 결과 제출은 `AUTHORING_JOB_NOT_CLAIMABLE`로 거부되고 몇 분간 돌린 결과가 통째로 버려진다.

실측 GENERATE ~250초 / REVIEW ~171초라 10분까지 여유가 2배 남짓뿐이다.

만료 lazy 평가의 다른 결과도 알아둘 것: `claimNext`와 `submitResult`는 만료를 **평가하지 않는다**. 30분 넘게 QUEUED였던 잡도 그대로 claim되고, 10분 넘긴 RUNNING 잡도 조회만 없었다면 정상 SUCCEEDED 된다. **DB만 보고 "정체됐다"고 판단하지 마라.**

## 진짜 상태는 DB로 확인한다

```sql
-- cli 말고 assignee_user_id·error를 봐라
SELECT id, kind, status, assignee_user_id, draft_id, started_at, error
  FROM generation_job ORDER BY id DESC LIMIT 5;

SELECT id, origin, status, topic, LENGTH(current_payload) FROM quiz_draft ORDER BY id DESC LIMIT 3;

-- [cost] 줄이 있으면 CLI는 완주한 것
SELECT line FROM job_log WHERE job_id = ? AND line LIKE '%cost%';
```

## 트러블슈팅

| 증상 | 원인 | 조치 |
|---|---|---|
| 잡이 계속 QUEUED | **브리지 로그인 계정 ≠ 잡 생성 계정** (가장 흔함) 또는 브리지 미기동 | `generation_job.assignee_user_id` 확인. `pnpm start login` 재실행 |
| `유효하지 않은 토큰입니다`가 **3초마다 무한 반복** | access·refresh 토큰 모두 만료 | `pnpm start login` 재로그인 |
| 저작 API가 **403 FORBIDDEN** | 로그인 계정이 ADMIN이 아님 | SKILL.md의 ADMIN 게이트 참조 |
| 브리지는 조용한데 대시보드가 FAILED | 서버 결과 검증 실패 | `generation_job.error` 확인 |
| 대시보드 터미널에 로그가 안 옴 | SSE 끊김 **또는** 브리지의 로그 전송 실패 | 브리지는 `postLogs` 실패를 **아무 흔적 없이 삼킨다**. 로그 정본은 `job_log` 테이블 |
| 잡이 RUNNING에 고착 | 브리지가 `postFail`마저 실패 | 코드가 인정한 한계. 누군가 조회해 lazy 만료가 걸릴 때까지 남는다 |

## 기타 코드 사실

- **Node ≥ 22 필수.** 런타임은 `tsx`(빌드 없이 직접 실행).
- `~/.thumbsup/bridge.json`에 `{serverUrl, cli, accessToken, refreshToken}` 저장(생성 시 `0600`). **토큰 갱신으로 덮어쓸 때 권한을 재설정하지 않는다.**
- 로그인 시 **비밀번호가 화면에 평문 에코**된다(내부 도구라 허용). 화면 공유·터미널 녹화 중이면 주의.
- 로그인 시점에 **ADMIN 여부·CLI 설치·구독 로그인 여부를 확인하지 않는다.** 문제는 `pnpm start` 후 403이 3초마다 도는 형태로만 드러난다.
- 토큰 갱신은 401 + `TOKEN_EXPIRED`일 때만, 정확히 1회 재시도. 단순 401은 갱신하지 않는다.
- claude 실패 판정은 `exitCode !== 0 || result 이벤트 없음`. 에러 메시지엔 **stderr 마지막 5줄만** 담긴다.
- **Ctrl+C가 진행 중인 잡을 보장해주지 않는다.** 코드가 하는 일은 루프 abort 하나뿐이고 자식 CLI 보호 장치가 없다 — 터미널 Ctrl+C는 프로세스 그룹 전체에 SIGINT를 보낸다. (README의 "진행 중인 잡을 마친 뒤 종료" 문구는 코드로 뒷받침되지 않는다.)
