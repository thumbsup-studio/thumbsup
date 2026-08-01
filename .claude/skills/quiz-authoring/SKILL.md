---
name: quiz-authoring
description: Thumbs Up 문제 저작 파이프라인. 웹 대시보드(/authoring)에서 문제를 생성·검수·개선·승인하고, 팀원 노트북의 로컬 브리지가 각자의 개인 AI CLI 구독으로 실행한다(#174·#175·#176). 브리지 기동·잡이 안 끝남·403 FORBIDDEN·생성 검증 실패·[[키워드]] 마커나 빈칸 규칙·프롬프트 수정·초안 승인·라이브 반영을 알아야 할 때 반드시 로드할 것. 사용자가 "브리지 어떻게 켜", "잡이 안 끝나", "생성이 안 돼", "저작 대시보드", "초안 승인", "문제 어떻게 생성해", "새 스텝 만들어줘", "커리큘럼 추가"라고 할 때 트리거.
---

# quiz-authoring — 문제 저작 파이프라인

웹 대시보드에서 문제를 만들고, **팀원 각자의 개인 AI CLI 구독**으로 실행한다. 공용 API 키로 토큰당 과금하지 않는 것이 이 구조의 존재 이유다.

```text
대시보드 /authoring ──POST /drafts/generate──▶ 서버: generation_job (QUEUED)
브리지(팀원 노트북) ──3초 폴링──▶ RUNNING, {prompt, outputSchema} 수령
     ├─ 개인 AI CLI 구독으로 헤드리스 실행
     ├─ POST .../logs   ──▶ job_log → SSE → 대시보드 터미널
     └─ POST .../result ──▶ 서버가 검증 → quiz_draft (DRAFT)

검수(REVIEW 잡) → revision 누적 → 승인 ──▶ 라이브 quiz 테이블 (즉시, 되돌릴 수 없음)
```

**프롬프트는 서버가 만든다.** 브리지는 프롬프트를 조립하지 않는 "멍청한 실행기"다.

코드: 서버 `server/.../quiz/authoring/` · 앱 `app/src/features/authoring/` · 브리지 `bridge/src/`
문제 생성·검증의 공유 코어는 `server/.../quiz/generation/`에 있다(패키지 이름은 레거시 CLI 시절 것).

## 어디를 읽을지

| 하려는 일 | 읽을 문서 |
|---|---|
| 브리지 켜기 · 잡이 QUEUED에서 안 움직임 · 구독 과금 걱정 · 격리 플래그 | [references/bridge.md](./references/bridge.md) |
| 대시보드 화면·API · 승인 흐름 · SSE 터미널이 이상함 | [references/dashboard.md](./references/dashboard.md) |
| 슬롯 구성 · `[[마커]]`·빈칸 규칙 · 검증 실패 · 프롬프트 수정 | [references/content-rules.md](./references/content-rules.md) |
| 라이브 문제를 SQL로 일괄 보정 · 과거 콘텐츠 출처 | [references/content-fix.md](./references/content-fix.md) |

브리지 격리 규약(구독 유지)을 건드렸는지 확인하려면:

```bash
python3 .claude/skills/quiz-authoring/scripts/check_bridge_isolation.py
```

## ⚠️ 잡이 안 끝난다고 코드부터 고치지 마라

**이 파이프라인에서 가장 비싼 실수는 정상 동작을 버그로 오인하는 것이다.** 과거 세션이 아래를 오해해 존재하지 않는 버그를 고치려 했다.

- `[system]` 이벤트 수백 개 → **정상.** 대부분 `thinking_tokens`로, 사고 중 3초당 1개씩 나오는 진행 표시다.
- `[rate_limit_event]` → **정상.** 페이로드가 `{"status":"allowed"}`인 정기 상태 핑이다.
- 몇 분째 RUNNING → **정상.** 5문제 생성은 4~6분 걸린다. 사고 중엔 로그가 멈춘 듯 보인다.

또한 **브리지 콘솔이 조용해도 잡은 실패했을 수 있다** — 서버 검증 실패는 HTTP 200 + `status:"FAILED"`로 돌아오고 브리지는 이를 성공처럼 넘긴다.

진짜 상태는 로그가 아니라 **DB로** 확인한다:

```sql
SELECT id, kind, status, assignee_user_id, draft_id, started_at, error
  FROM generation_job ORDER BY id DESC LIMIT 5;
```

⚠️ 그리고 **10분 넘긴 잡의 상태를 대시보드에서 조회하면 그 순간 잡이 죽는다**(만료가 lazy 평가라 조회가 판정을 확정시킨다). 증상별 해석은 [bridge.md](./references/bridge.md)에 있다.

## 잡 라이프사이클

`QUEUED → RUNNING → SUCCEEDED | FAILED`. 만료는 **QUEUED 30분 · RUNNING 10분**.

- 만료는 스케줄러가 아니라 **lazy 평가**다 — 조회·가드 시점에만 판정한다. 잡을 집을 때와 결과를 제출할 때는 아예 평가하지 않는다. **DB에 만료 시각이 지난 `RUNNING` 잡이 남아 있는 건 정상이다.**
- 잡은 CLI가 아니라 **`assignee_user_id`(계정)로 라우팅**된다. `generation_job.cli`는 잡이 끝날 때 사후 기록되므로 진행 중엔 항상 NULL이다 — **이 컬럼으로 진단하지 마라.**
- 초안: `origin ∈ {NEW, IMPROVE}`, `status ∈ {DRAFT, APPROVED}`. **승인 = 즉시 라이브이며 되돌리는 API가 없다.** IMPROVE 승인은 원본 문제를 파괴적으로 덮어쓴다(이전 내용은 draft의 rev1 payload에만 남는다).
- 한 문제당 **열린 IMPROVE 초안은 하나뿐**이다. 승인도 폐기도 않고 방치하면 그 문제는 재개선이 막힌다 — 초안 삭제 API가 아직 없어 DB를 직접 건드리는 것 말고 탈출구가 없다(#215).

## ADMIN 게이트 (fail-closed)

저작 전체(`/api/v1/authoring/**`)가 `hasRole("ADMIN")`이다. **대시보드와 브리지가 같은 게이트를 쓴다** — 브리지 엔드포인트도 `/api/v1/authoring/bridge/**` 아래다.

승격은 **토큰 발급 시점**에만 일어난다:

```java
// AuthService.issueTokens() → selfHealAdminRole()
if (!user.isAdmin() && authoringAdminProperties.adminEmails().contains(user.getEmail()))
    user.promoteToAdmin();
```

**ADMIN이 되려면 네 가지가 다 맞아야 한다:**

1. `thumbsup.authoring.admin-emails`에 이메일 등록 — prod는 SSM `/thumbsup/prod/AUTHORING_ADMIN_EMAILS`(콤마 구분), 로컬은 `application-local.yml`(기본값 `admin@thumbsup.local`)
2. 앱이 **부팅 시** 읽는다 → **파라미터를 배포 전에 등록**하면 배포가 곧 재시작이라 한 번에 끝난다. 나중에 등록하면 컨테이너 재시작 필요
3. 그 이메일로 **가입된 계정이 존재**해야 한다 (`contains()` — **대소문자까지 정확 일치**)
4. **재로그인** — role이 JWT 클레임이라 기존 토큰으론 admin이 아니다

> ⚠️ 이 레포는 public이고 signup이 무인증이다. **admin 이메일을 제3자가 선점 가입했는지 SSM 등록 전에 확인할 것** — 등록 순간 그 계정이 ADMIN이 된다.
>
> admin-emails에서 이메일을 빼도 **DB의 role은 강등되지 않는다**(수동 처리 필요).

role 없이 발급된 과거 토큰은 `JwtTokenProvider.DEFAULT_ROLE = "USER"`로 처리돼 기존 사용자는 영향받지 않는다.

## 로컬 풀스택 테스트

서버+MySQL 기동은 `thumbsup-local-server` 스킬과 메모리 `thumbsup-local-fullstack-test`를 따른다(로컬 Java가 21이 아니면 docker, SSM은 uid 마운트 함정이 있어 env-file로 우회).

저작 대시보드는 두 가지가 더 필요하다:

- `app/.env.local`에 **`NEXT_PUBLIC_API_URL=http://localhost:8080`** — 없으면 기본값이 **운영 API**라 로컬 화면으로 운영 문제를 승인하게 된다
- 브리지 `pnpm start` (대시보드 로그인 계정과 **같은 계정**으로 `pnpm start login`)

로컬 admin은 `admin@thumbsup.local`로 가입 후 로그인하면 승격된다.

## 관련

- `frontend-api` — 대시보드가 쓰는 envelope·토큰 규약
- `thumbsup-local-server` — 로컬 서버 기동 절차
- `merge` — Flyway 순서 게이트(과거 콘텐츠 보정 마이그레이션을 낼 때)
- `deploying` — `server/**` 변경만 백엔드 배포를 트리거한다(`bridge/**`는 아님)
