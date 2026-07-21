# PM 봇 (프로젝트 매니저) 설계

- 날짜: 2026-07-19
- 상태: 설계 확정 (구현 플랜 작성 전)
- 관련: 저작 파이프라인 브리지 `bridge/`(#175·#177) — CLI 어댑터 패턴 재사용
- Phase 2 상세 설계: [2026-07-21-pm-bot-phase2-emoji-design.md](./2026-07-21-pm-bot-phase2-emoji-design.md) — 분석 트리거를 🤖 이모지로 변경(§2 갱신됨)

## 1. 목적

팀용 프로젝트 매니저 봇. 세 가지 역할을 담당한다.

1. **명세 Q&A** — 서비스 기능 명세(스프린트 문서 + 추적 ID 체계)를 근거로 팀원 질문에 답변
2. **명세 자동 갱신** — Slack 대화를 분석해 명세 변경을 감지하고 PR로 제안, Slack 승인 시 자동 merge
3. **이슈·일정 관리** — GitHub 이슈 등록, 회의 액션아이템 추적, 주간 현황 리포트

## 2. 확정 결정

| 항목 | 결정 | 비고 |
|---|---|---|
| 채팅 플랫폼 | Slack 무료 플랜 | 카카오톡에서 이전. 90일 열람 제한은 봇 자체 저장으로 상쇄 |
| 명세 정본(SSoT) | thumbsup 모노레포(public)의 markdown | 스프린트 레포를 subtree로 병합. `F-xx`/`TRACE.md` 체계 유지 |
| 공개 범위 | 회의록·팀 문서 포함 전부 public 레포로 | 팀 인지 하에 결정. private 전환은 언제든 가능 |
| 봇 실행 위치 | 운영자(진) 노트북에 상주 프로세스 | EC2·컨테이너·공개 URL 불필요. Slack Socket Mode |
| LLM | 운영자 Claude 구독 — `claude -p` 직접 호출 | API 과금 없음. Mastra 등 API 키 전제 프레임워크 미도입 |
| 명세 수정 자율성 | PR 생성 → Slack 알림 → ✅ 이모지 승인 → 자동 merge | 사람 승인 없이는 명세 불변 |
| 이슈·보드 자율성 | 즉시 등록·변경 + Slack 사후 보고 | |
| 분석 범위 | 지정 채널만, 스레드에 🤖 이모지 = 명시적 사람 트리거 | 2026-07-21 갱신: 잠잠(2h) 자동 분석을 대체 — Phase 2 설계 문서 참고. 전 채널 감시·실시간 분석 안 함 |
| 일정 관리 범위 | 주간 현황 리포트 + 회의 액션아이템 추적 | 정체 이슈 리마인드·마일스톤 위험 감지는 비범위 |
| 팀원 접근 | Slack 멘션 + MCP stdio 패키지(각자 로컬 실행) | MCP 서버 호스팅 없음 |
| 스택 | TypeScript / Node ≥22, `bridge/`와 동일 계열 | Slack Bolt·better-sqlite3·execa·gh CLI (2026-07-21 갱신: Octokit 미도입 — 운영자 gh 인증 재사용) |

## 3. 구성 요소

### 3.1 `pm-bot/` — 상주 봇 (모노레포 새 워크스페이스)

운영자 노트북에서 pm2(또는 launchd)로 상시 실행되는 단일 Node 프로세스.

```
Slack Socket Mode ──▶ 수집기 ──▶ SQLite (messages, threads, action_items, jobs, qa_pending)
                                   │
                🤖 이모지 트리거 ─▶ 분석기 (claude -p, JSON 스키마 강제)
                                     ※ 분석 입력은 DB가 아니라 실시간 conversations.replies
                                   │
                    ┌──────────────┼───────────────┐
                    ▼              ▼               ▼
               명세 변경 감지    이슈 후보 감지    액션아이템 감지
                    │              │               │
               git PR 생성 +   즉시 등록·배치 +  SQLite 추적 +
               Slack 승인 대기  Slack 사후 보고   기한 경과 시 팔로업
```

내부 모듈:

- **수집기(collector)**: 지정 채널(설정 파일에 채널 ID 목록)의 메시지·스레드·이모지 이벤트를 SQLite에 적재. 기동 시 `conversations.history`로 마지막 저장 시점 이후를 백필.
- **리액션 핸들러**: 스레드에 🤖(`robot_face`) 이모지가 달리면 분석 잡 큐잉 (2026-07-21 갱신 — 잠잠 감지 워처를 대체). 라우팅·멱등성은 Phase 2 설계 문서 §4·§6.
- **분석기(analyzer)**: 스레드 전문 + 관련 명세 발췌를 `claude -p --json-schema`로 보내 구조화 판정을 받는다. `bridge/src/adapters/claude.ts`·`spawn.ts`의 어댑터(환경 격리·stream-json 파싱)를 재사용한다.
- **액션 실행기(actor)**: 분석 결과를 결정적으로 실행 — git 브랜치·커밋·PR(로컬 전용 clone에서 main 최신화 후 작업), GitHub 이슈 생성·보드 필드 배치(gh CLI, Projects v2 GraphQL), Slack 게시.
- **승인 핸들러(approver)**: 봇이 올린 명세 변경 알림 메시지에 ✅(white_check_mark) 반응이 달리면 해당 PR을 `--auto --squash`로 merge. ❌ 반응 시 PR 닫고 스레드에 사유 요청.
- **Q&A 핸들러**: `@PM봇` 멘션 → 간단한 키워드·헤딩 인덱스로 관련 명세 파일 선별 → 파일 내용을 동봉해 `claude -p` 답변 생성 → 스레드에 게시. 오프라인 중 들어온 멘션은 백필 시 `qa_pending`으로 잡아 순차 응답.
- **스케줄러(scheduler)**: 주간 리포트(월 09:00 KST, 보드 현황 요약 게시)와 액션아이템 기한 팔로업. 미가동으로 놓친 회차는 다음 기동 때 1회 캐치업.

### 3.2 분석 출력 스키마 (예시)

```json
{
  "spec_changes": [
    {
      "file": "docs/product/14_priority_matrix.md",
      "trace_ids": ["F-45"],
      "summary": "북마크(F-45)를 2순위에서 3순위(M3)로 연기",
      "rationale": "2026-07-18 #기획 스레드에서 MVP 범위 축소 합의",
      "edit_instruction": "F-45 행의 순위를 3으로 변경하고 비고에 연기 사유 추가"
    }
  ],
  "issue_candidates": [
    {
      "title": "feat(app): 북마크 UI 진입점 제거",
      "body": "…(근거 스레드 링크 포함)",
      "area": "S7 정리장",
      "milestone": "M3"
    }
  ],
  "action_items": [
    { "assignee": "U0ABCDEF", "content": "디자인 시안 공유", "due": "2026-07-21" }
  ],
  "nothing_found": false
}
```

`edit_instruction`을 받은 실행기는 **두 번째 `claude -p` 호출로 실제 markdown diff를 생성**한 뒤 git에 반영한다(판정과 편집을 분리해 오류 국소화).

### 3.3 `pm-mcp/` — 팀원용 MCP 패키지 (모노레포 새 워크스페이스)

stdio 방식 MCP 서버. 각 팀원이 Cursor·Claude Code에 로컬 등록해 실행한다. LLM 미사용 — 두뇌는 호출하는 쪽 AI.

| 도구 | 동작 | 인증 |
|---|---|---|
| `spec_search(query)` | 명세 markdown·TRACE 사슬 검색, 관련 항목 반환 | 불필요 (public 레포) |
| `spec_get(id)` | `F-xx`/`PG-xx`/이슈번호로 항목·사슬 조회 | 불필요 |
| `issue_create(...)` | 이슈 생성 + 보드 배치 | 각자 `gh` 토큰 |
| `board_status()` | 보드 현황 요약 | 각자 `gh` 토큰 |

명세 읽기는 로컬 clone 우선, 없으면 GitHub raw 조회.

### 3.4 데이터

- **명세 정본**: git 레포 (`docs/product/` — 병합된 스프린트 문서 + `TRACE.md`)
- **봇 작업 기억**: 로컬 SQLite 1파일 — `messages`, `threads`(분석 상태·마지막 분석 시각), `action_items`, `jobs`(분석·PR·승인 상태 머신), `qa_pending`

## 4. 사전 작업 (Phase 0)

1. **Slack 워크스페이스 신설**(무료 플랜) + 업무 채널 구성(#기획·#개발 등) + 팀 이전
2. **Slack 앱 생성**: Socket Mode 활성화, Bot Token Scopes — `channels:history`, `channels:read`, `chat:write`, `reactions:read`, `reactions:write`, `users:read`. 토큰 2종(bot token `xoxb-`, app-level token `xapp-`)은 운영자 노트북 `.env`에만 저장
3. **스프린트 레포 병합**: `git subtree add`로 커밋 이력 보존하며 `docs/product/`로 이동, 스프린트 레포는 아카이브. 내부 문서가 public이 됨을 팀에 최종 공지
4. **봇 커밋 규약 예외 등록**: 봇의 명세 PR은 이슈 연결 없이 `docs(spec): <요약> (pm-bot)` 형식 허용 — CONTRIBUTING에 1줄 추가

## 5. 에러 처리

- `claude -p` 실패·타임아웃: 1회 재시도 후 실패 시 Slack에 원문 로그 요약과 함께 알림. 조용한 실패 금지
- PR 충돌·CI 실패·merge 불가: 자동 해결 시도하지 않고 Slack에 수동 처리 요청
- Slack 연결 끊김: Bolt 재연결에 위임, 재연결 시 백필 1회
- 분석기 오판(잘못된 명세 변경): 승인 게이트가 방어선. ❌ 반응으로 반려하면 해당 스레드는 재분석 제외 목록에 등록

## 6. 테스트 전략

- **분석 프롬프트 골든 테스트**: 대표 스레드 샘플(명세 변경·이슈·액션아이템·아무것도 없음) → 기대 판정 스냅샷. vitest
- **어댑터·실행기 단위 테스트**: claude 어댑터 목킹, git/Octokit 호출은 dry-run 모드
- **e2e**: 테스트 전용 Slack 채널 + 테스트 레포로 수집→분석→PR→승인→merge 전 구간 1회 통과 확인

## 7. 구축 단계

| Phase | 내용 | 검증 기준 |
|---|---|---|
| 0 | Slack 셋업 + 스프린트 레포 병합 + 규약 예외 | 팀이 Slack에서 대화, `docs/product/` 정본화 |
| 1 | 수집·저장·백필 + @멘션 명세 Q&A (읽기 전용) | 오프라인 후 재기동 시 공백 0건, Q&A 정답률 체감 확인 |
| 2 | 스레드 분석 → 명세 PR → ✅ 승인 merge | 대표 시나리오 1건 전 구간 통과 |
| 3 | 이슈 등록·액션아이템 추적·주간 리포트 | 실제 회의 1회분에서 이슈·액션아이템 누락 없이 처리 |
| 4 | `pm-mcp/` 패키지 + 팀원 온보딩 문서 | 팀원 1명 이상 Cursor/Claude Code 연결 성공 |

## 8. 비범위 (Non-goals)

- Mastra 등 에이전트 프레임워크 도입 (API 키 전제라 구독 CLI 제약과 충돌, 효용 대비 과함)
- EC2·컨테이너 배포, 원격 MCP 호스팅, 백업 LLM
- 전 채널 상시 감시, 실시간 스트리밍 분석
- 스레드 잠잠(2h) 자동 분석 — 🤖 이모지 명시 트리거로 대체 (2026-07-21, 추후 확장 후보)
- 정체 이슈 리마인드, 마일스톤 위험 감지 (추후 확장 후보)
- 노트북 오프라인 시 실시간 응답 보장 (수집·승인은 백필로 복구, Q&A는 지연 응답)

## 9. 운영 규칙 (팀 공지 사항)

- PM 봇은 운영자 노트북이 켜져 있을 때 살아 있다. 꺼진 동안의 대화·승인 이모지는 재기동 시 소급 처리된다
- 명세를 바꾸고 싶으면 지정 채널 스레드에서 논의한 뒤 스레드에 🤖 이모지를 남기면 된다 — 봇이 분석해 PR로 제안한다
- 봇의 명세 PR은 ✅ 이모지 하나로 merge된다. 내용이 틀렸으면 ❌ 후 스레드에 정정 내용을 남긴다
