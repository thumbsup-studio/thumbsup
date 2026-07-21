---
name: pm-bot
description: Slack에서 팀 대화를 수집하고 명세 근거 Q&A에 답하는 PM 봇(#202) 운영. 봇 기동·종료·pm2 상주, Slack 앱 셋업(매니페스트·토큰 2종·채널 초대), 멘션 사용법, DB 조회, 크래시 진단, Phase 1 한계를 알아야 할 때. 사용자가 "슬랙 봇 켜줘", "PM 봇 켜/꺼", "봇 서버 띄워", "봇이 답을 안 해", "봇이 죽었어", "Slack 봇 셋업", "명세 물어보기", "스레드 분석", "명세 PR 승인", "이모지 트리거"라고 할 때 트리거.
---

# pm-bot — Slack PM 봇 (#202, Phase 1·2)

지정한 Slack 채널의 대화를 로컬 SQLite에 모으고, 멘션하면 레포의 명세 markdown을 근거로 답하는 상주 봇. Phase 2부터 스레드에 🤖 이모지를 달면 스레드를 분석해 **명세 수정 PR**(✅ 승인 시 자동 머지)과 **GitHub 이슈 등록·갱신**(Thumbs Up Roadmap 보드 배치)까지 수행한다.

**팀원은 아무것도 설치할 필요가 없다.** Slack에서 `@pm-bot` 멘션만 하면 된다. 봇은 운영자 노트북 한 대에서만 돈다.

## 아키텍처

```
[Slack 채널]
    │  Socket Mode (공개 URL 불필요 — 그래서 노트북에서 돈다)
    ▼
[pm-bot (운영자 노트북, pm2 상주)]
    ├─ 수집기 ──────▶ SQLite (messages, qa_pending)
    ├─ 백필 (재기동 시 놓친 구간 복구)
    └─ Q&A: 명세 검색 → claude -p (개인 구독) → 스레드 답변
              │
              └─ docs/specs/*.md 를 섹션 단위로 인덱싱
```

`bridge/`와 **무관하다.** 둘 다 `claude -p`로 개인 구독을 쓰지만 `import` 관계가 없고, `pm-bot/src/adapters/`는 bridge에서 **복사해 온 독립 사본**이다(`spawn.ts` 첫 줄 주석). bridge가 꺼져 있어도 pm-bot은 돈다.

## 기동·종료

### "봇 켜줘" 요청을 받았을 때 (에이전트용 절차)

**1. 이미 떠 있는지 먼저 확인한다. 중복 기동 금지.**

```bash
pgrep -fl "pm-bot.*src/index.ts"
```

프로세스가 있으면 켜지 말고 "이미 실행 중"이라고 보고한다. 같은 앱 토큰으로 두 개를 띄우면 Slack이 이벤트를 **한쪽에만** 배달하므로(브로드캐스트 아님) 두 DB에 대화가 쪼개져 쌓인다. 기록이 갈라지면 되돌리기 어렵다.

**2. 기동.** 반드시 `pm-bot/`에서 실행한다 — `dbPath`·`specDir`이 cwd 상대경로라 다른 데서 띄우면 DB가 엉뚱한 곳에 생기고 명세를 못 찾는다.

```bash
cd /Users/kmjnnhyk/DEV/thumbsup/pm-bot && pnpm start
```

백그라운드로 띄울 때는 로그를 파일로 받아야 진단할 수 있다:

```bash
cd /Users/kmjnnhyk/DEV/thumbsup/pm-bot && pnpm start > /tmp/pm-bot.log 2>&1
```

**3. 성공 확인.** 이 두 줄이 **모두** 떠야 한다. 5~10초 걸린다.

```
[pm-bot] Socket Mode 연결됨 — 채널 C0BK8M5N7EU 감시 중
[pm-bot] 백필 완료 — 신규 N건
```

첫 줄만 뜨고 끝나면 백필에서 죽은 것이다(대개 `not_in_channel`) → 아래 함정 참고. **로그에 두 번째 줄이 없으면 기동 성공으로 보고하지 말 것.** 프로세스 생존도 같이 확인한다:

```bash
pgrep -f "pm-bot.*src/index.ts" > /dev/null && echo 실행중 || echo 죽음
```

### 상주 (pm2)

```bash
cd /Users/kmjnnhyk/DEV/thumbsup/pm-bot
pm2 start "pnpm start" --name pm-bot
pm2 logs pm-bot
pm2 stop pm-bot
```

### 종료

SIGTERM을 보낸다. `app.stop()` → DB close 순으로 정리하고 exit 0으로 끝난다.

```bash
pkill -TERM -f "pm-bot.*src/index.ts"
```

`SIGKILL`(`-9`)은 쓰지 말 것 — WAL이 정리되지 않은 채 끊긴다.

### 최초 1회

```bash
cd /Users/kmjnnhyk/DEV/thumbsup/pm-bot && pnpm install
```

`.env`·`pm-bot.config.json`이 없으면 기동이 실패한다 → Phase 0 셋업 참고.

## 사용법

채널에서 멘션한다. **`@PM봇`이 아니라 `@pm-bot`이다** (아래 함정 참고).

```
@pm-bot 퀴즈 재도전 기능 어떻게 설계됐어?
@pm-bot #63 어떻게 됐어?
```

답변까지 10~30초. 이슈 번호(`#63`)나 스펙 ID(`F-45`)를 넣으면 검색 정확도가 크게 오른다 — ID 매치에 100점, 일반 단어는 1점씩이라 ID 하나가 단어 100개를 이긴다.

비용은 **답변 1건당 $0.08~0.12** (운영자 개인 Claude 구독). 팀원이 많이 물어보면 운영자 구독을 쓴다는 점을 기억할 것.

### 🤖 스레드 분석 (Phase 2)

분석하고 싶은 스레드의 아무 메시지에 🤖(robot_face) 반응을 단다. 채널 멤버 누구나 가능.

- 접수되면 봇이 👀를 달고, 완료되면 스레드에 결과(명세 PR·이슈 링크)를 답글로 남긴다
- 명세 변경은 봇이 올린 "📝 명세 변경 제안" 답글에 ✅를 달면 auto-merge, ❌면 PR 클로즈
- 같은 스레드에 🤖를 다시 달면: 새 메시지가 없으면 "이미 처리됨", 있으면 재분석(기존 이슈는 중복 생성 대신 갱신)
- 실패하면 ⚠️ 답글이 남는다 — 🤖를 다시 달면 재시도
- 비용: 분석 1건당 claude 호출 2회+ ≈ $0.15~0.25 (운영자 구독)

## Phase 0 — Slack 앱 셋업 (최초 1회)

### 1. 앱 생성 — https://api.slack.com/apps

`Create New App` → **`From an app manifest`** → `pm-bot/slack-app-manifest.yml` 내용을 YAML 탭에 붙여넣기.

수동으로 스코프를 클릭해 넣지 말 것. 매니페스트가 스코프 7개·이벤트 3개·Socket Mode를 한 번에 설정한다.

### 2. 토큰 2개 — 서로 다른 화면에서 나온다

| 토큰 | 위치 | 주의 |
|---|---|---|
| `xapp-…` | Basic Information → App-Level Tokens → Generate | **`connections:write` 스코프 필수** |
| `xoxb-…` | OAuth & Permissions → Install to Workspace | 설치해야 발급됨 |

`pm-bot/.env`에 넣는다 (`.env.example` 참고):

```
SLACK_BOT_TOKEN=xoxb-...
SLACK_APP_TOKEN=xapp-...
```

### 3. 채널 설정

`pm-bot/pm-bot.config.json` (`pm-bot.config.example.json` 참고):

```json
{
  "channels": ["C0BK8M5N7EU"],
  "dbPath": "./pm-bot.sqlite",
  "specDir": "../docs/specs",
  "github": {
    "repo": "thumbsup-studio/thumbsup",
    "projectOwner": "thumbsup-studio",
    "projectNumber": 2,
    "specDirInRepo": "docs/specs",
    "account": "kmjnnhyk"
  }
}
```

- `channels`는 채널 **이름이 아니라 ID**(`C`로 시작). Slack에서 채널명 클릭 → 정보 창 맨 아래.
- `specDir`은 현재 `../docs/specs`. example의 `../docs/product`는 스프린트 레포 subtree 병합 후에나 존재한다(미실행).
- `github`은 Phase 2 전용(선택). **없으면 GitHub 액션 비활성, 수집·Q&A만 동작**한다 — 명세 PR·이슈 생성 없이 Phase 1처럼 쓸 수 있다.

### 4. 채널에 초대

```
/invite @pm-bot
```

**이걸 빠뜨리면 봇이 부팅 직후 죽는다.** 스코프가 있어도 봇은 자기가 멤버인 채널만 읽는다.

### 5. Phase 2 업그레이드 — 앱 재설치 (최초 1회)

매니페스트에 `reaction_added` 이벤트·`reactions:write` 스코프가 추가됐다. 기존 앱에 반영하려면:

1. https://api.slack.com/apps → 앱 선택 → **App Manifest** → `pm-bot/slack-app-manifest.yml` 내용으로 교체 → Save
2. 스코프가 바뀌었으므로 **Reinstall to Workspace** 버튼이 뜬다 → 재설치 (토큰은 그대로 유효)
3. 봇 재기동 후 테스트 채널 스레드에 🤖를 달아 👀가 달리는지 확인

## ⚠️ 함정

### `not_in_channel` 하나에 프로세스 전체가 죽는다

```
Error: An API error occurred: not_in_channel
```

백필이 채널별로 에러를 격리하지 않아 채널 하나가 잘못되면 봇 전체가 exit 1로 내려간다. **pm2 상주 중이면 재시작 → 같은 에러 → 무한 루프**가 된다.

대응: 해당 채널에 `/invite @pm-bot`. 채널을 archive하거나 봇을 kick해도 같은 증상이 난다. 채널을 여러 개 감시할 때 하나만 어긋나도 나머지 정상 채널까지 멈추므로, 로그에 `not_in_channel`이 보이면 **모든** 설정 채널의 멤버십을 확인할 것. (Phase 2에서 채널별 격리 예정)

### `display_name`에 한글을 쓸 수 없다

매니페스트의 `features.bot_user.display_name`은 Slack 사용자명으로 변환 가능해야 해서 ASCII만 된다. `PM봇`을 넣으면 앱 생성이 거부된다:

```
The display_name cannot be converted to a username: `PM봇`
```

그래서 앱 이름(`display_information.name`)은 `PM봇`이지만 **멘션은 `@pm-bot`** 이다. README 구버전에 `@PM봇` 예시가 남아 있으면 그게 틀린 것.

### `app_mentions:read`를 빠뜨리면 앱 생성이 거부된다

`app_mention` 이벤트를 구독하려면 같은 이름의 스코프가 필요하다. 매니페스트에 이미 들어 있으니 수동으로 스코프를 만들 때만 주의.

### `connections:write` 없는 app token

Socket Mode 연결에 필요하다. 없으면 부팅하자마자 소켓 연결에서 죽는다.

### gh 활성 계정이 jinhyeok-bell이면 GitHub 액션이 꺼진다

기동 로그에 `gh 활성 계정 불일치` 경고가 뜨면 명세 PR·이슈 생성이 비활성 상태다(수집·Q&A는 정상).
`gh auth switch --user kmjnnhyk` 후 재기동.

## Phase 1 한계 (설계상 의도된 것 + 실측으로 드러난 것)

| 한계 | 내용 |
|---|---|
| 오프라인 스레드 답글 | 봇이 꺼진 동안 **기존 스레드**에 달린 답글은 백필이 못 잡는다. `conversations.history`가 스레드 답글을 반환하지 않는 구조적 한계 |
| 오프라인 멘션 | 봇이 꺼진 동안의 `@pm-bot` 질문은 소급 응답 없음. 재기동 후 **다시 멘션**해야 한다 |
| 문서 전체 질문에 부분 답변 | `search()`가 상위 **5개 섹션**만 넘긴다. 섹션 단위라 "이 기능 어떻게 설계됐어?" 같은 질문엔 문서 일부만 본다. 실측: 16섹션짜리 문서에서 3섹션만 전달되고 나머지 2칸은 무관한 문서가 차지 |
| 노이즈 | 점수 필터가 `score > 0`이라 답이 없어도 상위 5개가 무조건 채워진다. "기능"·"설계" 같은 흔한 단어가 거의 모든 문서에 매치되기 때문 |

세 번째·네 번째는 **답변이 틀린다는 뜻이 아니다.** 봇은 발췌가 부족하면 "이 부분은 확인할 수 없다"고 명시한다(환각 방어 프롬프트). 다만 답이 반쪽일 수 있으니, 중요한 질문은 ID(`#63`)를 넣어 검색을 좁히는 편이 낫다.

## DB 들여다보기

```bash
cd pm-bot
sqlite3 pm-bot.sqlite "select ts, user, text from messages order by ts"
sqlite3 pm-bot.sqlite "select id, status, error from qa_pending"
sqlite3 pm-bot.sqlite "select thread_ts, status, error from analyses"
sqlite3 pm-bot.sqlite "select pr_number, status from spec_prs"
```

`qa_pending.status`: `pending` → `done` / `failed`(`error`에 사유). 답변 실패 시 스레드에도 `⚠️ 답변 생성에 실패했어요`가 올라간다 — 조용히 실패하지 않는다.

`*.sqlite*`는 `pm-bot/.gitignore`가 덮는다. **이 레포는 public이므로 DB를 레포 루트로 옮기지 말 것** — 루트 `.gitignore`엔 sqlite 규칙이 없어서 Slack 원문이 그대로 커밋된다.

## Slack 없이 답변 품질만 보기

`qa-dryrun.ts`가 Slack·DB를 건너뛰고 검색 → 프롬프트 → `claude -p`만 돌린다. 검색이 엉뚱한 문서를 물어오는지 확인할 때 쓴다.

```bash
cd pm-bot
pnpm tsx qa-dryrun.ts ../docs/specs "빈칸 정답 매칭 규칙이 뭐야?"
```

히트한 섹션 목록과 최종 답변을 같이 출력한다. 히트 0건이면 봇도 "모른다"고 답한다.

Phase 2 스레드 분석도 dryrun이 있다. `analyze-dryrun.ts`는 Slack 반응 이벤트·DB·`gh` PR 생성 없이 fetch → 판정 → (`--edit` 시) 편집 diff 미리보기까지만 돈다. `config.github`이 있어야 한다(열린 이슈·보드 옵션 조회용, 읽기 전용).

```bash
cd pm-bot
pnpm tsx --env-file-if-exists=.env analyze-dryrun.ts <channel> <thread_ts> [--edit]
```

## 관련

- 스펙: [`docs/specs/2026-07-19-pm-bot-design.md`](../../../docs/specs/2026-07-19-pm-bot-design.md) · [`2026-07-21-pm-bot-phase2-emoji-design.md`](../../../docs/specs/2026-07-21-pm-bot-phase2-emoji-design.md)
- 플랜: [`docs/plans/2026-07-19-pm-bot-phase1.md`](../../../docs/plans/2026-07-19-pm-bot-phase1.md) · [`2026-07-21-pm-bot-phase2-emoji.md`](../../../docs/plans/2026-07-21-pm-bot-phase2-emoji.md)
- 이슈: #202 (Phase 4까지 열어둠)
- 팀원용 MCP 패키지(`pm-mcp/`)는 Phase 4 — 각자 Cursor·Claude Code에 붙이는 stdio 서버. 미구현
