# PM 봇 Phase 2 — 🤖 이모지 트리거 분석 설계

- 날짜: 2026-07-21
- 상태: 설계 확정 (구현 플랜 작성 전)
- 관련: [2026-07-19-pm-bot-design.md](./2026-07-19-pm-bot-design.md)(전체 설계), 이슈 #202, Phase 1 구현 PR #207

## 1. 목적

팀원이 Slack 스레드(팀원 텍스트 대화 또는 허들 AI 요약 노트)에 🤖(`robot_face`) 이모지를 남기면, 봇이 그 스레드를 분석해:

1. 관련 기능 명세를 수정하는 PR을 올리고 (✅ 승인 시 자동 merge)
2. Thumbsup Roadmap 보드에 이슈를 새로 만들거나 기존 이슈를 수정한다

원 설계의 Phase 2~3 영역이며 트리거만 다르다 — "스레드 잠잠 2시간 후 자동 분석" 대신 **명시적 사람 트리거**. 오탐이 적고 분석 시점을 팀이 통제한다.

## 2. 확정 결정

| 항목 | 결정 | 비고 |
|---|---|---|
| 트리거 | 🤖(`robot_face`) 이모지 = 명시적 사람 트리거 | 원 설계의 "잠잠 2h 자동 분석"을 대체. 자동 분석은 비범위로 이동 |
| 트리거 권한 | 감시 채널 멤버 누구나 | 명세 변경은 ✅ 승인 게이트가 뒤에 있어 안전. 이슈는 즉시 등록이라 오탐 시 수동 정리 |
| 분석 입력 | DB가 아니라 이모지 시점 `conversations.replies` 실시간 fetch | 허들 AI 노트는 봇 메시지라 수집 필터(`!ev.user`)에 걸려 DB에 없다. 팀원 스레드도 같은 경로로 통일 |
| GitHub 연동 | gh CLI + execa (Octokit 미도입) | 새 npm 의존성 0개, 운영자 gh 인증 재사용(PAT 불필요). Projects v2는 `gh api graphql` |
| 명세 수정 자율성 | PR → 스레드 답글 → ✅ 승인 → auto-merge | 원 설계 §2 유지 |
| 이슈 자율성 | 즉시 등록·수정 + 스레드 사후 보고. 신규 이슈는 보드 **Backlog**에 배치(트리아지 대기) | 원 설계 §2 유지 + 백로그 규칙 |
| 새 이슈 vs 기존 수정 | 열린 이슈 목록을 판정 프롬프트에 동봉, claude가 create/update 판단 | 별도 중복 검색 로직 없음 |
| 작업 레포 | `pm-bot/.workrepo/` blobless clone (`git clone --filter=blob:none`) | 워크트리 미사용 — 상주 데몬이 운영자 작업 레포와 `.git`을 공유하면 락 경합·장애 반경 문제 |
| 범위 | 이모지 기능만 | Phase 2 백로그 8건은 별도 작업(§9), `action_items` 추적도 비범위(Phase 3) |

## 3. 이벤트 배관 변경 (Slack 앱)

- `slack-app-manifest.yml` `bot_events`에 `reaction_added` 추가
- `reactions:write` 스코프 추가 — 접수 확인 👀 이모지용. 원 설계 Phase 0에 계획됐으나 현 매니페스트에 누락돼 있었다
- **앱 재설치 필요** — 절차는 구현 시 SKILL.md에 기록

## 4. 아키텍처

```
Slack reaction_added ──▶ 리액션 라우터
                          ├─ 대상 ts가 spec_prs.message_ts → 승인 분기 (✅ merge / ❌ close)
                          ├─ robot_face + 감시 채널      → analyses 큐잉 + 👀 반응
                          └─ 그 외 (봇 자신의 반응 포함)  → 무시
                                        │
                              drain 루프 (순차, qa_pending 패턴)
                                        ▼
                       ① conversations.replies 실시간 fetch   ← DB 안 씀
                          (봇 메시지 = AI 요약 노트 포함 전부)
                                        ▼
                       ② 판정 — claude -p (JSON 스키마)
                          입력: 스레드 전문 + specindex 검색 발췌
                                + 열린 이슈 목록(gh issue list)
                                        ▼
                       ③ 실행 (결정적 코드)
                          ├─ spec_changes → 편집(claude -p 2차, 치환 목록)
                          │    → .workrepo 브랜치·커밋·push → gh pr create
                          │    → 스레드에 "✅로 승인" 답글 (ts를 spec_prs에 기록)
                          └─ issue_actions → gh issue create/edit
                               + gh api graphql (Roadmap 추가 + Area·Status 필드)
                               → 스레드에 사후 보고 답글
```

### 4.1 리액션 라우터

- `reaction_added` 이벤트 하나로 승인·트리거 두 기능을 분기한다. 반응이 달린 메시지 ts가 `spec_prs.message_ts`에 있으면 승인 분기, `robot_face`이고 감시 채널이면 트리거 분기, 그 외 무시.
- 봇 자신이 단 반응(👀)도 `reaction_added`로 들어오므로 기동 시 `auth.test`로 얻은 봇 user ID와 일치하면 무시한다.
- `reaction_removed`는 무시 — 뗐다 다시 붙여도 §6 멱등성 규칙이 적용된다.
- 🤖는 스레드의 **어느 메시지에 달려도** 동작한다: `conversations.replies({ ts: item.ts, limit: 1 })`로 해당 메시지의 `thread_ts`를 얻어 스레드 부모 기준으로 큐잉한다. 스레드 없는 단독 메시지면 그 메시지 하나가 분석 대상.
- 핸들러는 큐에 넣고 👀만 달고 끝낸다. 실제 작업은 drain 루프가 순차 처리 — 재기동에도 견딘다.

### 4.2 판정 출력 스키마

```json
{
  "spec_changes": [{
    "file": "2026-07-19-pm-bot-design.md",
    "summary": "…", "rationale": "…",
    "edit_instruction": "…"
  }],
  "issue_actions": [{
    "kind": "create | update",
    "number": 123,
    "title": "feat(app): …", "body": "…(근거 스레드 링크 포함)",
    "area": "…"
  }],
  "nothing_found": false
}
```

- `number`는 `kind: "update"`일 때만. `area`는 Roadmap 보드 필드값. Status는 판정하지 않는다 — 신규 이슈는 결정적 코드가 **Backlog**로 고정 배치하고, update는 보드 Status를 건드리지 않는다(트리아지는 사람 몫).
- 원 설계 §3.2 스키마에서 `action_items`를 제외한 형태(Phase 3 잔여).

### 4.3 명세 편집 — 문자열 치환 (claude -p 2차)

판정과 편집을 분리하는 원 설계 §3.2 원칙 유지. 대상 파일 전문 + `edit_instruction`을 주고 **파일 전체 재출력이 아니라 치환 목록**을 받는다:

```json
{ "edits": [{ "old": "정확히 매치될 원문", "new": "바뀔 내용" }] }
```

적용은 결정적 코드가 수행 — 매치가 0건이거나 2건 이상이면 그 자리에서 실패 처리한다(조용히 틀린 파일을 만들지 않는다).

### 4.4 git·PR 규칙

- 브랜치 `docs/pm-bot-<thread_ts>-<last_msg_ts>`(런마다 고유), 커밋 `docs(spec): <요약> (pm-bot)` — 원 설계 §4의 봇 커밋 규약 예외. CONTRIBUTING 반영 여부는 플랜에서 확인하고 없으면 이번에 1줄 추가
- `.workrepo`는 잡마다 `fetch` + `reset --hard origin/main`으로 최신화
- 기동 시 `gh auth status`로 활성 계정이 kmjnnhyk인지 검증(jinhyeok-bell이면 403) — 아니면 부팅 거부가 아니라 **GitHub 액션만 비활성 + 경고 로그** (수집·Q&A는 계속 동작)
- ✅ → `gh pr merge --auto --squash` (main 브랜치 보호 체크 통과 후 자동 머지 — docs 변경도 server-ci가 paths-filter로 job 내부 스킵하므로 체크는 통과), ❌ → `gh pr close` + 스레드에 사유 요청
- 재분석 시 기존 awaiting PR은 close(superseded 마킹)하고 `docs/pm-bot-<thread_ts>-<last_msg_ts>` 고유 브랜치로 새 PR을 만든다 — 같은 head 브랜치의 중복 PR 생성 불가·승인된 PR 내용 무단 변경 방지

## 5. 데이터 (SQLite 추가 테이블)

```sql
-- 🤖 분석 잡 + 멱등성 기록 — 스레드당 1행
CREATE TABLE analyses (
  channel      TEXT NOT NULL,
  thread_ts    TEXT NOT NULL,   -- 스레드 부모 ts (단독 메시지면 그 메시지 ts)
  status       TEXT NOT NULL,   -- pending → running → done | failed
  requested_by TEXT NOT NULL,   -- 🤖 누른 사람 (기록용, 키 아님)
  last_msg_ts  TEXT,            -- 분석에 포함된 마지막 메시지 ts → 재트리거 판단
  result_json  TEXT,            -- { prUrl, issueUrls } 결과 링크
  error        TEXT,
  PRIMARY KEY (channel, thread_ts)
);

-- 승인 대기 PR — ✅/❌가 달린 메시지의 역참조
CREATE TABLE spec_prs (
  pr_number   INTEGER PRIMARY KEY,
  pr_url      TEXT NOT NULL,
  channel     TEXT NOT NULL,
  message_ts  TEXT NOT NULL,    -- 봇이 올린 승인 대기 답글의 ts
  thread_ts   TEXT NOT NULL,
  status      TEXT NOT NULL     -- awaiting → approved | rejected | superseded
);
```

`requested_by`를 PK에서 뺀 이유: 키에 넣으면 팀원 두 명이 같은 스레드에 🤖를 누를 때 중복 분석이 된다. 멱등성 단위는 스레드다.

## 6. 멱등성 — 같은 스레드 🤖 재반응 시

| 현재 상태 | 동작 |
|---|---|
| `pending` / `running` | 무시 (이미 진행 중) |
| `done` + 새 메시지 없음 | "이미 처리됨" + 기존 결과 링크 답글 |
| `done` + 새 메시지 있음 | 재분석 — 이전 결과 링크를 판정 프롬프트에 동봉해 새 이슈 대신 기존 이슈 update로 유도 |
| `failed` | 재시도 허용 |

- 새 메시지 여부는 실시간 fetch한 마지막 ts와 `last_msg_ts` 비교로 판단
- 재기동 시 `running` 잔류 잡은 `pending`으로 리셋 후 drain

## 7. 에러 처리 (원 설계 §5 정책 유지)

- claude 호출 실패: 1회 재시도(`qa.ts`의 `runWithRetry` 재사용)
- git·gh 실패: 재시도 없이 즉시 스레드에 ⚠️ 답글 + 수동 처리 요청
- 부분 실패: 명세 PR은 성공, 이슈 등록만 실패 같은 경우 — 성공 링크와 실패 사유를 한 답글에 함께 보고
- `nothing_found`여도 "등록할 것을 찾지 못했다" 답글 — 조용한 무반응 금지
- 실패는 `analyses.status = failed`로 남아 🤖 재반응으로 재시도 가능

## 8. 테스트 전략

- **단위(vitest)**: 리액션 라우팅(🤖/✅/❌ 분기·채널·이모지·봇 자신 필터), §6 멱등성 상태 전이 전체, 치환 적용기(매치 0·1·2건), 판정·편집 프롬프트 빌더. gh·git 호출은 Phase 1의 `HistoryClient`처럼 인터페이스로 추상화해 목킹
- **`analyze-dryrun.ts` 하네스** (qa-dryrun 전례): 실제 채널+thread_ts를 주면 fetch → 판정 → 편집 diff 미리보기까지 돌리고 gh 실행만 스킵 — Slack 이벤트 없이 분석 품질 검증
- **실 Slack e2e**: ① 텍스트 스레드 🤖 → PR + 이슈 + 보드 배치 확인 ② ✅ → auto-merge ③ AI 요약 노트 스레드 🤖 → 실시간 fetch 경로 확인 ④ 같은 스레드 재반응 → "이미 처리됨"

## 9. 비범위 (Non-goals)

- 스레드 잠잠(2h) 자동 분석 — 이모지 트리거로 대체, 추후 확장 후보로 격하
- `action_items` 추적·주간 리포트 (Phase 3)
- Phase 2 백로그 — 별도 작업으로 분리: 오프라인 스레드 답글 백필, `thread_broadcast` 수집, 오프라인 멘션 소급 큐잉, 성공경로 postMessage 실패 오분류, shutdown drain 미대기, `not_in_channel` 채널별 격리, search limit=5 부분 답변, score>0 노이즈 플로어
