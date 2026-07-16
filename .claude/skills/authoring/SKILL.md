---
name: authoring
description: 웹 대시보드에서 퀴즈를 생성·검수·개선하고 팀원 개인 AI CLI 구독으로 로컬 브리지가 실행하는 저작 파이프라인(#174·#175·#176). 브리지 기동·로그인·트러블슈팅, 잡 상태 진단(로그 이벤트 해석), draft→approved 라이프사이클, ADMIN 게이트, 로컬 풀스택 테스트 방법을 알아야 할 때. 사용자가 "브리지 어떻게 켜", "잡이 안 끝나", "생성이 안 돼", "저작 대시보드", "초안 승인"이라고 할 때 트리거.
---

# authoring — 문제 저작 파이프라인 (#174·#175·#176)

웹 대시보드(`/authoring`)에서 문제를 **생성·검수·개선**하고, 팀원 노트북의 **로컬 브리지**가 각자의 **개인 AI CLI 구독**으로 실행한다. 공용 API 키로 토큰당 과금하지 않는 것이 이 구조의 존재 이유다.

기존 `quiz-generation` 스킬(#26, 서버가 Elice API를 직접 호출하는 CLI 전용 파이프라인)과 **별개로 공존**한다. 이쪽은 프롬프트 조립·검증기를 재사용하되 실행 주체가 다르다.

## 아키텍처

```
[대시보드 /authoring]  ──POST /drafts/generate {topic}──▶  [서버]
                                                            generation_job (QUEUED)
[브리지 (팀원 노트북)]  ──GET /bridge/jobs/next (롱폴)──▶   → RUNNING, {prompt, outputSchema} 반환
     │
     ├─ claude CLI 실행 (개인 구독, 헤드리스)
     ├─ POST /bridge/jobs/{id}/logs  {lines[]}  ──▶ job_log → SSE 팬아웃 → 대시보드 터미널
     └─ POST /bridge/jobs/{id}/result {payload} ──▶ 서버가 검증 → quiz_draft (DRAFT)
                                                     실패 시 POST /bridge/jobs/{id}/fail

[대시보드]  검수(REVIEW 잡) → quiz_draft_revision 누적 → 승인 → quiz 테이블(= 라이브)
```

- **프롬프트는 서버가 만든다.** 브리지는 프롬프트를 조립하지 않는 "멍청한 실행기"다 — 서버가 렌더링해 잡에 실어 보낸다(`AuthoringPromptFactory`).
- **잡 상태**: `QUEUED → RUNNING → SUCCEEDED | FAILED`. 만료는 **QUEUED 30분 · RUNNING 10분**(`AuthoringJobService`).
  ⚠️ **만료는 스케줄러가 아니라 lazy 평가다** — 가드·조회 시점에만 판정한다. 아무도 조회하지 않으면 **DB엔 만료 시각이 지난 잡이 계속 `RUNNING`으로 남아 있다.** DB만 보고 "정체됐다"고 판단하지 마라.
- **초안**: `origin ∈ {NEW, IMPROVE}`, `status ∈ {DRAFT, APPROVED}`. **승인 = 즉시 라이브 반영**.

**코드**: 서버 `server/.../quiz/authoring/` · 앱 `app/src/features/authoring/` · 브리지 `bridge/src/`
**설치·로그인·실행 절차 정본**: [`bridge/README.md`](../../../bridge/README.md) — 여기 복붙하지 말고 그쪽을 볼 것

## 브리지 기동 (요약)

```bash
cd bridge
pnpm start login   # 서버URL·이메일·비밀번호·CLI 선택 → ~/.thumbsup/bridge.json
pnpm start         # 잡 큐 폴링 시작. Ctrl+C는 진행 중인 잡을 마친 뒤 종료
```

전제: `claude setup-token`으로 **구독 로그인이 먼저** 돼 있어야 한다. 로그인 계정은 **ADMIN**이어야 한다(아래 게이트).

## ⚠️ 진단 함정 — 로그 이벤트를 오해하지 마라

**이 절이 이 스킬의 핵심이다.** 2026-07-15 세션이 아래 셋을 전부 오해해 "존재하지 않는 버그"를 고치려 했다.

| 증상 | 오해 | 사실 |
|---|---|---|
| `[system]` 이벤트가 수십~수백 개 | "에이전틱 툴 루프에 빠졌다" | 대부분 **`system/thinking_tokens`** — 모델이 사고하는 동안 **약 3초당 1개**씩 나오는 진행 표시. 정상이며 격리로 못 없앤다 |
| `[rate_limit_event]` 출현 | "구독 레이트리밋에 걸려 실패했다" | 페이로드가 **`{"status":"allowed"}`** 인 **정기 상태 핑**. "1+1"짜리 성공 실행에서도 뜬다 |
| 잡이 몇 분째 RUNNING | "정체됐다" | 5문제(≈25KB JSON) 생성은 **정상적으로 4~6분** 걸린다. 사고 중엔 로그가 멈춘 것처럼 보인다(stream-json은 완성된 메시지 단위로만 이벤트를 낸다) |

**진짜로 끝났는지·실패했는지는 로그가 아니라 DB로 확인한다:**

```sql
SELECT id, kind, status, cli, started_at, updated_at FROM generation_job ORDER BY id DESC LIMIT 5;
SELECT id, origin, status, topic, LENGTH(current_payload) FROM quiz_draft ORDER BY id DESC LIMIT 3;
SELECT line FROM job_log WHERE job_id=? AND line LIKE '%cost%';   -- [cost] 줄이 있으면 CLI는 완주함
```

**짧은 프롬프트로 프로브하면 오판한다** — 사고 시간이 없어 `thinking_tokens`가 안 나오고 훅 이벤트만 보인다. 장시간 실행으로 재현할 것.

**`--max-turns`는 claude CLI에 존재하지 않는 플래그다**(2.1.210 확인). 단발 완성 강제는 `--tools ""`로 한다.

## 구독 유지 규칙 (어기면 개인 구독 대신 API 과금)

- 자식 프로세스 env에서 `ANTHROPIC_API_KEY`·`OPENAI_API_KEY`·`GOOGLE_API_KEY` 등을 **제거한다** (`bridge/src/adapters/spawn.ts`의 `BLOCKED_ENV_KEYS`).
- **`claude --bare`를 절대 쓰지 마라.** "훅·auto-memory·CLAUDE.md 자동탐색 skip"이라 딱 맞아 보이지만 *"OAuth and keychain are never read"* — `ANTHROPIC_API_KEY`를 요구해서 **구독 인증이 깨진다.**

## 격리 플래그 — 왜 붙어 있나 (제거 금지)

`bridge/src/adapters/claude.ts`는 `claude -p`에 아래를 넘긴다:

```
--tools ""  --strict-mcp-config  --setting-sources ""  --disable-slash-commands
--system-prompt <최소>   +   cwd: tmpdir()
```

없으면 **운영자의 개인 환경 전체를 상속한다** — 실측: "1+1" 한 줄에 **45,416 토큰**(툴 30·MCP 10·슬래시 213·훅·프로젝트 CLAUDE.md·**운영자 개인 메모리 인덱스와 이메일**). 붙이면 **616 토큰**.

문제는 비용만이 아니다. **팀원마다 개인 설정이 달라 같은 주제도 생성 결과가 달라진다.**

- `--tools ""`를 줘도 `StructuredOutput`은 남아 `--json-schema` 구조화 출력이 그대로 동작한다.
- `--system-prompt`로 기본 시스템 프롬프트를 덮는 이유: 서버가 이미 `EliceClient.SYSTEM_PROMPT`를 사용자 프롬프트에 넣어 보낸다(`AuthoringPromptFactory.generatePrompt`).
- `--model`은 **고정하지 않는다** — 운영자 개인 모델 설정을 존중한다(팀 결정).

## 트러블슈팅

| 증상 | 원인 | 조치 |
|---|---|---|
| `유효하지 않은 토큰입니다`가 **3초마다 무한 반복** | access·refresh 토큰 모두 만료 | `pnpm start login` 재로그인. (브리지가 안내 없이 에러만 뱉는 건 알려진 후속 과제) |
| 저작 API가 **403 FORBIDDEN** | 로그인 계정이 ADMIN이 아님 | 아래 ADMIN 게이트 참조 |
| 잡이 계속 QUEUED | 브리지 미기동 또는 다른 CLI 잡만 있음 | `pnpm start` 확인, `generation_job.cli` 확인 |
| 대시보드 터미널에 로그가 안 옴 | SSE 끊김 | 새로고침. 로그 정본은 `job_log` 테이블 |

## ADMIN 게이트 (fail-closed)

저작 전체(`/api/v1/authoring/**`)가 `hasRole("ADMIN")`이다. 승격은 **토큰 발급 시점**에만 일어난다:

```java
// AuthService.issueTokens() → selfHealAdminRole()
if (!user.isAdmin() && authoringAdminProperties.adminEmails().contains(user.getEmail()))
    user.promoteToAdmin();
```

**ADMIN이 되려면 네 가지가 다 맞아야 한다:**

1. SSM `/thumbsup/prod/AUTHORING_ADMIN_EMAILS`(로컬은 `application-local.yml`)에 이메일 등록
2. 앱이 **부팅 시** SSM을 읽는다 → **파라미터를 배포 전에 등록**하면 배포가 곧 재시작이라 한 번에 끝난다. 나중에 등록하면 컨테이너 재시작 필요
3. 그 이메일로 **가입된 계정이 존재**해야 한다 (`contains()` — **대소문자까지 정확 일치**)
4. **재로그인** — role이 JWT 클레임이라 기존 토큰으론 admin이 아니다

> ⚠️ 이 레포는 public이고 signup이 무인증이다. **admin 이메일을 제3자가 선점 가입했는지 SSM 등록 전에 확인할 것** — 등록 순간 그 계정이 ADMIN이 된다.
>
> admin-emails에서 이메일을 빼도 **DB의 role은 강등되지 않는다**(수동 처리 필요).

role 없이 발급된 과거 토큰은 `JwtTokenProvider.DEFAULT_ROLE = "USER"`로 처리돼 기존 사용자는 영향받지 않는다.

## 로컬 풀스택 테스트

```bash
# 서버 — 로컬 Java가 17이면 docker 필수(프로젝트는 21). SSM은 uid 마운트 함정이 있어 env-file로 우회
aws --profile thumbsup configure export-credentials   # 임시 크레덴셜 → env 파일
docker run --name thumbsup-server --env-file <env> -p 8080:8080 ... server-app:latest
# MySQL 컨테이너 + app `pnpm dev`(:3000) + bridge `pnpm start`
```

- 로컬 admin: `application-local.yml`의 `admin-emails`에 `admin@thumbsup.local` — **그 이메일로 가입 후 로그인**하면 ADMIN 승격
- 크레덴셜 만료 시 `export-credentials` 재실행
- 자세한 함정은 메모리 `thumbsup-local-fullstack-test` 참조

## CLI별 상태 (2026-07-15)

| CLI | 상태 |
|---|---|
| **claude** | ✅ 실기기 검증(구독 헤드리스 + `--json-schema` + `structured_output`). 팀 주력 |
| **codex** | ⚠️ `--output-schema`가 strict 비호환이라 플래그 제거됨. 팀 미구독 — 실측 미검증 |
| **gemini** | ⚠️ 팀 미구독 — 미검증. 격리 플래그도 미적용 |

## 실측 기준값 (2026-07-15, 격리 적용 후)

| 잡 | 소요 | 비용 |
|---|---|---|
| GENERATE (5문제 ≈ 25KB) | ~250초 | ~$0.49 |
| REVIEW (단건, 초안 전문 포함 프롬프트 26KB) | ~171초 | ~$0.50 |

이 범위를 크게 벗어나면 격리 플래그가 빠졌는지 의심할 것.

## 관련

- `quiz-generation` — #26 Elice 파이프라인. 프롬프트 조립(`QuizGenerationPromptBuilder`)과 검증기(`GeneratedQuizValidator`·`CodeSnippetValidator`·`KeywordMarkerValidator`)를 이 파이프라인이 **그대로 재사용**한다. 생성 프롬프트를 고치려면 그 스킬의 마커·빈칸 규칙을 반드시 함께 볼 것
- `frontend-api` — 대시보드가 쓰는 envelope·토큰 규약
- `deploying` — `server/**` 변경만 백엔드 배포를 트리거한다(`bridge/**`는 아님)
