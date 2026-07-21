# PM 봇 Phase 2 — 🤖 이모지 트리거 분석 구현 플랜

> **For agentic workers:** Implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Slack 스레드에 🤖 이모지가 달리면 봇이 스레드를 분석해 명세 수정 PR(✅ 승인 → auto-merge)과 GitHub 이슈 등록/갱신(Roadmap 보드 배치)을 수행한다.

**Architecture:** `reaction_added` 이벤트를 라우터가 승인(✅/❌)·트리거(🤖) 분기로 나누고, 트리거는 SQLite 큐(`analyses`)에 넣어 drain 루프가 순차 처리한다. 분석 입력은 DB가 아니라 이모지 시점의 `conversations.replies` 실시간 fetch(봇 메시지 = 허들 AI 노트 포함). 판정과 명세 편집은 `claude -p` 2회 호출로 분리하고, GitHub 실행은 gh CLI 래퍼(`github.ts`)가 결정적으로 수행한다. 명세 PR은 `pm-bot/.workrepo/`(blobless clone)에서 만든다.

**Tech Stack:** TypeScript / Node ≥22 / ESM, @slack/bolt(Socket Mode), better-sqlite3, execa + gh CLI, vitest. 새 npm 의존성은 `@slack/web-api`(dryrun 하네스용) 1개.

**스펙:** [`docs/specs/2026-07-21-pm-bot-phase2-emoji-design.md`](../specs/2026-07-21-pm-bot-phase2-emoji-design.md)

## Global Constraints

- 작업 경로: `~/DEV/thumbsup__worktrees/feat/202-pm-bot-phase2/pm-bot/` (워크트리, 브랜치 `feat/202-pm-bot-phase2` 생성됨). 모든 상대 경로는 `pm-bot/` 기준
- ESM — 로컬 import는 `./foo.js` 확장자 필수. 타입 전용은 `import type`
- pm-bot은 독립 패키지 — 레포 내 다른 워크스페이스(`app/`, `bridge/`) import 금지
- public 레포 — 토큰·Slack 원문·`*.sqlite*`·`.workrepo/` 커밋 금지
- gh·git 호출은 전부 CLI(execa) — Octokit 미도입. claude 호출 실패만 1회 재시도(`runWithRetry`), gh·git 실패는 재시도 없이 즉시 보고
- GitHub 대상: repo `thumbsup-studio/thumbsup`, 프로젝트 **"Thumbs Up Roadmap" #2** (org `thumbsup-studio`). 보드 필드(2026-07-21 실측): `Status`(Todo/In Progress/Done), `Area`(INFRA 환경/S0 로그인/…/QA 검수) — 단 필드·옵션은 하드코딩하지 않고 GraphQL로 런타임 조회
- 커밋 형식: `<type>(pm-bot): <한국어 요약> (#202)` — commit 스킬 규약. 커밋 명령엔 `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` 푸터
- 테스트 실행: `cd pm-bot && pnpm vitest run test/<파일>` (전체는 `pnpm test`), 타입은 `pnpm typecheck`

---

### Task 1: DB 확장 — `analyses`·`spec_prs` 테이블

**Files:**
- Modify: `src/db.ts`
- Test: `test/db.test.ts` (기존 파일에 describe 추가)

**Interfaces:**
- Consumes: 기존 `openDb()` 구조 (prepare 문 + 반환 객체 메서드 패턴)
- Produces (이후 태스크 전부가 사용):
  ```ts
  export type AnalysisRow = { channel: string; threadTs: string; status: string; requestedBy: string; lastMsgTs: string | null; resultJson: string | null; error: string | null };
  export type SpecPrRow = { prNumber: number; prUrl: string; channel: string; messageTs: string; threadTs: string; status: string };
  // PmDb에 추가되는 메서드
  requestAnalysis(q: { channel: string; threadTs: string; requestedBy: string }): "queued" | "in_progress";
  nextPendingAnalysis(): AnalysisRow | null;
  markAnalysisRunning(channel: string, threadTs: string): void;
  markAnalysisDone(channel: string, threadTs: string, lastMsgTs: string, resultJson: string): void;
  markAnalysisFailed(channel: string, threadTs: string, error: string): void;
  resetRunningAnalyses(): number;   // running → pending, 리셋 건수 반환 (재기동용)
  insertSpecPr(row: SpecPrRow): void;
  specPrByMessage(channel: string, messageTs: string): SpecPrRow | null;
  markSpecPr(prNumber: number, status: "approved" | "rejected"): void;
  ```

- [ ] **Step 1: 실패하는 테스트 작성** — `test/db.test.ts`에 추가

```ts
describe("analyses", () => {
  it("requestAnalysis는 신규 스레드를 pending으로 큐잉한다", () => {
    const db = openDb(":memory:");
    expect(db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" })).toBe("queued");
    expect(db.nextPendingAnalysis()?.threadTs).toBe("1.0");
  });

  it("pending·running 중복 요청은 in_progress로 무시된다", () => {
    const db = openDb(":memory:");
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    expect(db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U2" })).toBe("in_progress");
    db.markAnalysisRunning("C1", "1.0");
    expect(db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U2" })).toBe("in_progress");
  });

  it("done 재요청은 lastMsgTs·resultJson을 보존한 채 재큐잉된다", () => {
    const db = openDb(":memory:");
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    db.markAnalysisRunning("C1", "1.0");
    db.markAnalysisDone("C1", "1.0", "5.0", '{"issueUrls":[]}');
    expect(db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U2" })).toBe("queued");
    const row = db.nextPendingAnalysis();
    expect(row?.lastMsgTs).toBe("5.0");
    expect(row?.resultJson).toBe('{"issueUrls":[]}');
    expect(row?.requestedBy).toBe("U2");
  });

  it("failed 재요청은 error를 비우고 재큐잉된다", () => {
    const db = openDb(":memory:");
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    db.markAnalysisRunning("C1", "1.0");
    db.markAnalysisFailed("C1", "1.0", "boom");
    expect(db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" })).toBe("queued");
    expect(db.nextPendingAnalysis()?.error).toBeNull();
  });

  it("resetRunningAnalyses는 running만 pending으로 되돌린다", () => {
    const db = openDb(":memory:");
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    db.markAnalysisRunning("C1", "1.0");
    db.requestAnalysis({ channel: "C1", threadTs: "2.0", requestedBy: "U1" });
    db.markAnalysisRunning("C1", "2.0");
    db.markAnalysisDone("C1", "2.0", "2.0", "{}");
    expect(db.resetRunningAnalyses()).toBe(1);
    expect(db.nextPendingAnalysis()?.threadTs).toBe("1.0");
  });
});

describe("spec_prs", () => {
  it("승인 대기 메시지 ts로 역참조한다", () => {
    const db = openDb(":memory:");
    db.insertSpecPr({ prNumber: 7, prUrl: "https://x/7", channel: "C1", messageTs: "9.0", threadTs: "1.0", status: "awaiting" });
    expect(db.specPrByMessage("C1", "9.0")?.prNumber).toBe(7);
    expect(db.specPrByMessage("C1", "8.0")).toBeNull();
    db.markSpecPr(7, "approved");
    expect(db.specPrByMessage("C1", "9.0")?.status).toBe("approved");
  });
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd pm-bot && pnpm vitest run test/db.test.ts`
Expected: FAIL — `requestAnalysis is not a function`

- [ ] **Step 3: 구현** — `src/db.ts`

SCHEMA 상수에 추가:

```sql
CREATE TABLE IF NOT EXISTS analyses (
  channel      TEXT NOT NULL,
  thread_ts    TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'pending',
  requested_by TEXT NOT NULL,
  last_msg_ts  TEXT,
  result_json  TEXT,
  error        TEXT,
  PRIMARY KEY (channel, thread_ts)
);
CREATE TABLE IF NOT EXISTS spec_prs (
  pr_number  INTEGER PRIMARY KEY,
  pr_url     TEXT NOT NULL,
  channel    TEXT NOT NULL,
  message_ts TEXT NOT NULL,
  thread_ts  TEXT NOT NULL,
  status     TEXT NOT NULL DEFAULT 'awaiting'
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_spec_prs_msg ON spec_prs (channel, message_ts);
```

타입 export 추가(파일 상단), prepare 문과 메서드 추가:

```ts
export type AnalysisRow = { channel: string; threadTs: string; status: string; requestedBy: string; lastMsgTs: string | null; resultJson: string | null; error: string | null };
export type SpecPrRow = { prNumber: number; prUrl: string; channel: string; messageTs: string; threadTs: string; status: string };
```

```ts
const getAnalysisStmt = db.prepare(
  `SELECT channel, thread_ts AS threadTs, status, requested_by AS requestedBy,
          last_msg_ts AS lastMsgTs, result_json AS resultJson, error
   FROM analyses WHERE channel = ? AND thread_ts = ?`,
);
const insertAnalysisStmt = db.prepare(
  `INSERT INTO analyses (channel, thread_ts, status, requested_by) VALUES (?, ?, 'pending', ?)`,
);
const requeueAnalysisStmt = db.prepare(
  `UPDATE analyses SET status = 'pending', requested_by = ?, error = NULL WHERE channel = ? AND thread_ts = ?`,
);
const nextAnalysisStmt = db.prepare(
  `SELECT channel, thread_ts AS threadTs, status, requested_by AS requestedBy,
          last_msg_ts AS lastMsgTs, result_json AS resultJson, error
   FROM analyses WHERE status = 'pending' ORDER BY thread_ts LIMIT 1`,
);
const analysisStatusStmt = db.prepare(`UPDATE analyses SET status = ? WHERE channel = ? AND thread_ts = ?`);
const analysisDoneStmt = db.prepare(
  `UPDATE analyses SET status = 'done', last_msg_ts = ?, result_json = ?, error = NULL WHERE channel = ? AND thread_ts = ?`,
);
const analysisFailStmt = db.prepare(`UPDATE analyses SET status = 'failed', error = ? WHERE channel = ? AND thread_ts = ?`);
const resetRunningStmt = db.prepare(`UPDATE analyses SET status = 'pending' WHERE status = 'running'`);
const insertSpecPrStmt = db.prepare(
  `INSERT INTO spec_prs (pr_number, pr_url, channel, message_ts, thread_ts, status)
   VALUES (@prNumber, @prUrl, @channel, @messageTs, @threadTs, @status)`,
);
const specPrByMsgStmt = db.prepare(
  `SELECT pr_number AS prNumber, pr_url AS prUrl, channel, message_ts AS messageTs, thread_ts AS threadTs, status
   FROM spec_prs WHERE channel = ? AND message_ts = ?`,
);
const markSpecPrStmt = db.prepare(`UPDATE spec_prs SET status = ? WHERE pr_number = ?`);
```

반환 객체 메서드:

```ts
requestAnalysis(q: { channel: string; threadTs: string; requestedBy: string }): "queued" | "in_progress" {
  const row = getAnalysisStmt.get(q.channel, q.threadTs) as AnalysisRow | undefined;
  if (!row) {
    insertAnalysisStmt.run(q.channel, q.threadTs, q.requestedBy);
    return "queued";
  }
  if (row.status === "pending" || row.status === "running") return "in_progress";
  requeueAnalysisStmt.run(q.requestedBy, q.channel, q.threadTs); // done의 last_msg_ts·result_json 보존 — drain의 재트리거 판단 근거
  return "queued";
},
nextPendingAnalysis(): AnalysisRow | null {
  return (nextAnalysisStmt.get() as AnalysisRow | undefined) ?? null;
},
markAnalysisRunning(channel: string, threadTs: string): void {
  analysisStatusStmt.run("running", channel, threadTs);
},
markAnalysisDone(channel: string, threadTs: string, lastMsgTs: string, resultJson: string): void {
  analysisDoneStmt.run(lastMsgTs, resultJson, channel, threadTs);
},
markAnalysisFailed(channel: string, threadTs: string, error: string): void {
  analysisFailStmt.run(error, channel, threadTs);
},
resetRunningAnalyses(): number {
  return resetRunningStmt.run().changes;
},
insertSpecPr(row: SpecPrRow): void {
  insertSpecPrStmt.run(row);
},
specPrByMessage(channel: string, messageTs: string): SpecPrRow | null {
  return (specPrByMsgStmt.get(channel, messageTs) as SpecPrRow | undefined) ?? null;
},
markSpecPr(prNumber: number, status: "approved" | "rejected"): void {
  markSpecPrStmt.run(status, prNumber);
},
```

- [ ] **Step 4: 통과 확인**

Run: `cd pm-bot && pnpm vitest run test/db.test.ts && pnpm typecheck`
Expected: PASS (기존 8개 + 신규 6개)

- [ ] **Step 5: 커밋**

```bash
git add pm-bot/src/db.ts pm-bot/test/db.test.ts
git commit -m "feat(pm-bot): analyses·spec_prs 테이블 — 분석 큐·승인 대기 PR 저장 (#202)"
```

---

### Task 2: 리액션 라우터 — `src/reactions.ts`

**Files:**
- Create: `src/reactions.ts`
- Test: `test/reactions.test.ts`

**Interfaces:**
- Consumes: Task 1의 `SpecPrRow`
- Produces (Task 7의 index.ts가 사용):
  ```ts
  export type ReactionEvent = { user: string; reaction: string; item: { type: string; channel: string; ts: string } };
  export type Route =
    | { kind: "trigger"; channel: string; ts: string; user: string }
    | { kind: "approve"; pr: SpecPrRow; user: string }
    | { kind: "reject"; pr: SpecPrRow; user: string }
    | { kind: "ignore" };
  export type RouteDeps = { botUserId: string; channels: string[]; specPrByMessage(channel: string, messageTs: string): SpecPrRow | null };
  export function routeReaction(ev: ReactionEvent, deps: RouteDeps): Route;
  ```

- [ ] **Step 1: 실패하는 테스트 작성** — `test/reactions.test.ts`

```ts
import { describe, expect, it } from "vitest";
import type { SpecPrRow } from "../src/db.js";
import { routeReaction } from "../src/reactions.js";

const PR: SpecPrRow = { prNumber: 7, prUrl: "https://x/7", channel: "C1", messageTs: "9.0", threadTs: "1.0", status: "awaiting" };
const deps = (over: Partial<{ botUserId: string; channels: string[]; pr: SpecPrRow | null }> = {}) => ({
  botUserId: over.botUserId ?? "UBOT",
  channels: over.channels ?? ["C1"],
  specPrByMessage: (c: string, ts: string) => (c === "C1" && ts === "9.0" ? (over.pr === undefined ? PR : over.pr) : null),
});
const ev = (over: Partial<{ user: string; reaction: string; type: string; channel: string; ts: string }> = {}) => ({
  user: over.user ?? "U1",
  reaction: over.reaction ?? "robot_face",
  item: { type: over.type ?? "message", channel: over.channel ?? "C1", ts: over.ts ?? "1.0" },
});

describe("routeReaction", () => {
  it("감시 채널의 🤖는 trigger", () => {
    expect(routeReaction(ev(), deps())).toEqual({ kind: "trigger", channel: "C1", ts: "1.0", user: "U1" });
  });
  it("감시 밖 채널·다른 이모지·message 아닌 item·봇 자신은 ignore", () => {
    expect(routeReaction(ev({ channel: "C9" }), deps()).kind).toBe("ignore");
    expect(routeReaction(ev({ reaction: "eyes" }), deps()).kind).toBe("ignore");
    expect(routeReaction(ev({ type: "file" }), deps()).kind).toBe("ignore");
    expect(routeReaction(ev({ user: "UBOT" }), deps()).kind).toBe("ignore");
  });
  it("승인 대기 메시지의 ✅는 approve, ❌는 reject", () => {
    expect(routeReaction(ev({ reaction: "white_check_mark", ts: "9.0" }), deps())).toEqual({ kind: "approve", pr: PR, user: "U1" });
    expect(routeReaction(ev({ reaction: "x", ts: "9.0" }), deps())).toEqual({ kind: "reject", pr: PR, user: "U1" });
  });
  it("승인 대기 메시지의 🤖·기타 이모지는 ignore — 봇 답글 재분석 방지", () => {
    expect(routeReaction(ev({ reaction: "robot_face", ts: "9.0" }), deps()).kind).toBe("ignore");
    expect(routeReaction(ev({ reaction: "tada", ts: "9.0" }), deps()).kind).toBe("ignore");
  });
  it("이미 처리된(awaiting 아닌) PR 메시지의 ✅는 ignore", () => {
    expect(routeReaction(ev({ reaction: "white_check_mark", ts: "9.0" }), deps({ pr: { ...PR, status: "approved" } })).kind).toBe("ignore");
  });
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd pm-bot && pnpm vitest run test/reactions.test.ts`
Expected: FAIL — `Cannot find module '../src/reactions.js'`

- [ ] **Step 3: 구현** — `src/reactions.ts` (파일 전체)

```ts
import type { SpecPrRow } from "./db.js";

export type ReactionEvent = { user: string; reaction: string; item: { type: string; channel: string; ts: string } };

export type Route =
  | { kind: "trigger"; channel: string; ts: string; user: string }
  | { kind: "approve"; pr: SpecPrRow; user: string }
  | { kind: "reject"; pr: SpecPrRow; user: string }
  | { kind: "ignore" };

export type RouteDeps = {
  botUserId: string;
  channels: string[];
  specPrByMessage(channel: string, messageTs: string): SpecPrRow | null;
};

/** reaction_added 하나로 승인(✅/❌)과 분석 트리거(🤖)를 분기한다 (스펙 §4.1). */
export function routeReaction(ev: ReactionEvent, deps: RouteDeps): Route {
  if (ev.user === deps.botUserId || ev.item.type !== "message") return { kind: "ignore" };
  const pr = deps.specPrByMessage(ev.item.channel, ev.item.ts);
  if (pr) {
    // 승인 대기 답글에 달린 반응 — 🤖를 포함한 다른 이모지는 전부 무시해 봇 답글 재분석을 막는다
    if (pr.status !== "awaiting") return { kind: "ignore" };
    if (ev.reaction === "white_check_mark") return { kind: "approve", pr, user: ev.user };
    if (ev.reaction === "x") return { kind: "reject", pr, user: ev.user };
    return { kind: "ignore" };
  }
  if (ev.reaction === "robot_face" && deps.channels.includes(ev.item.channel))
    return { kind: "trigger", channel: ev.item.channel, ts: ev.item.ts, user: ev.user };
  return { kind: "ignore" };
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd pm-bot && pnpm vitest run test/reactions.test.ts && pnpm typecheck`
Expected: PASS (5개)

- [ ] **Step 5: 커밋**

```bash
git add pm-bot/src/reactions.ts pm-bot/test/reactions.test.ts
git commit -m "feat(pm-bot): reaction_added 라우터 — 🤖 트리거·✅/❌ 승인 분기 (#202)"
```

---

### Task 3: 판정·편집 프롬프트 + 치환 적용기 — `src/analysis.ts` 1부

**Files:**
- Create: `src/analysis.ts`
- Modify: `src/adapters/claude.ts` (`runWithRetry` 이동), `src/qa.ts` (로컬 `runWithRetry` 삭제 후 import)
- Test: `test/analysis.test.ts`

**Interfaces:**
- Consumes: `SpecSection`(specindex.ts), `CliAdapter`/`AdapterInput`/`AdapterHooks`(adapters/types.ts)
- Produces:
  ```ts
  // adapters/claude.ts에 추가 (qa.ts·analysis.ts 공용)
  export function runWithRetry(adapter: CliAdapter, input: AdapterInput, hooks: AdapterHooks): Promise<string>;
  // analysis.ts
  export const ANALYSIS_SYSTEM_PROMPT: string;
  export type ThreadMsg = { user: string; text: string };
  export type SpecChange = { file: string; summary: string; rationale: string; edit_instruction: string };
  export type IssueAction = { kind: "create" | "update"; number?: number; title: string; body: string; area: string; status: string };
  export type JudgeResult = { spec_changes: SpecChange[]; issue_actions: IssueAction[]; nothing_found: boolean };
  export type PrevResult = { prUrl?: string; issueUrls: string[] };
  export function buildJudgePrompt(args: { thread: ThreadMsg[]; permalink: string; hits: SpecSection[]; openIssues: Array<{ number: number; title: string; labels: string[] }>; areaOptions: string[]; statusOptions: string[]; prev?: PrevResult }): { prompt: string; outputSchema: object };
  export function buildEditPrompt(args: { file: string; content: string; instruction: string }): { prompt: string; outputSchema: object };
  export function applyEdits(content: string, edits: Array<{ old: string; new: string }>): string; // 매치 ≠1이면 throw
  ```

- [ ] **Step 1: 실패하는 테스트 작성** — `test/analysis.test.ts`

```ts
import { describe, expect, it } from "vitest";
import { applyEdits, buildEditPrompt, buildJudgePrompt } from "../src/analysis.js";

describe("applyEdits", () => {
  it("정확히 1건 매치면 치환한다", () => {
    expect(applyEdits("a b c", [{ old: "b", new: "B" }])).toBe("a B c");
  });
  it("매치 0건이면 throw", () => {
    expect(() => applyEdits("a b c", [{ old: "z", new: "Z" }])).toThrow(/0건/);
  });
  it("매치 2건 이상이면 throw — 조용히 틀린 파일 생성 금지", () => {
    expect(() => applyEdits("a b b", [{ old: "b", new: "B" }])).toThrow(/2건/);
  });
  it("순차 적용 — 앞 치환 결과에 뒤 치환이 적용된다", () => {
    expect(applyEdits("x y", [{ old: "x", new: "y" }, { old: "y y", new: "done" }])).toBe("done");
  });
});

describe("buildJudgePrompt", () => {
  const base = {
    thread: [{ user: "U1", text: "북마크 3순위로 미루자" }],
    permalink: "https://slack/p1",
    hits: [{ file: "spec.md", heading: "우선순위", ids: ["F-45"], body: "북마크는 2순위" }],
    openIssues: [{ number: 3, title: "북마크 UI", labels: ["app"] }],
    areaOptions: ["S2 홈", "S7 정리장"],
    statusOptions: ["Todo", "Done"],
  };
  it("스레드·명세 발췌·열린 이슈·permalink를 프롬프트에 담는다", () => {
    const { prompt } = buildJudgePrompt(base);
    expect(prompt).toContain("북마크 3순위로 미루자");
    expect(prompt).toContain("북마크는 2순위");
    expect(prompt).toContain("#3 북마크 UI");
    expect(prompt).toContain("https://slack/p1");
  });
  it("area·status 스키마 enum은 보드 옵션을 그대로 쓴다", () => {
    const { outputSchema } = buildJudgePrompt(base);
    const s = JSON.stringify(outputSchema);
    expect(s).toContain("S7 정리장");
    expect(s).toContain("Todo");
  });
  it("prev가 있으면 중복 등록 방지 지시를 담는다", () => {
    const { prompt } = buildJudgePrompt({ ...base, prev: { prUrl: "https://gh/pr/1", issueUrls: ["https://gh/i/2"] } });
    expect(prompt).toContain("https://gh/pr/1");
    expect(prompt).toContain("https://gh/i/2");
  });
});

describe("buildEditPrompt", () => {
  it("파일 내용과 지시를 담고 edits 스키마를 요구한다", () => {
    const { prompt, outputSchema } = buildEditPrompt({ file: "spec.md", content: "# 제목\n본문", instruction: "순위를 3으로" });
    expect(prompt).toContain("# 제목");
    expect(prompt).toContain("순위를 3으로");
    expect(JSON.stringify(outputSchema)).toContain("edits");
  });
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd pm-bot && pnpm vitest run test/analysis.test.ts`
Expected: FAIL — `Cannot find module '../src/analysis.js'`

- [ ] **Step 3: `runWithRetry`를 adapters/claude.ts로 이동**

`src/adapters/claude.ts` — import에 타입 추가 후 파일 끝에:

```ts
import type { AdapterHooks, AdapterInput, CliAdapter } from "./types.js";

/** adapter.run 실패 시 1회 재시도 후에야 실패로 처리한다 (스펙 §5). qa·분석 공용. */
export async function runWithRetry(adapter: CliAdapter, input: AdapterInput, hooks: AdapterHooks): Promise<string> {
  try {
    return await adapter.run(input, hooks);
  } catch (err) {
    hooks.onLog(`[retry] 1차 실패, 재시도: ${err instanceof Error ? err.message : String(err)}`);
    return adapter.run(input, hooks);
  }
}
```

`src/qa.ts` — 로컬 `runWithRetry` 함수(주석 포함) 삭제, import 추가:

```ts
import { runWithRetry } from "./adapters/claude.js";
```

Run: `cd pm-bot && pnpm vitest run test/qa.test.ts` → PASS 유지 확인 (기존 8개)

- [ ] **Step 4: `src/analysis.ts` 구현** (1부 — 프롬프트·치환. drain은 Task 6에서 이어서)

```ts
import type { SpecSection } from "./specindex.js";

export const ANALYSIS_SYSTEM_PROMPT =
  "너는 떰즈업 팀의 PM 어시스턴트다. 요청받은 JSON만 출력한다. 제공된 스레드와 명세 발췌만 근거로 판단하고, 근거가 약하면 항목을 만들지 않는다.";

export type ThreadMsg = { user: string; text: string };
export type SpecChange = { file: string; summary: string; rationale: string; edit_instruction: string };
export type IssueAction = { kind: "create" | "update"; number?: number; title: string; body: string; area: string; status: string };
export type JudgeResult = { spec_changes: SpecChange[]; issue_actions: IssueAction[]; nothing_found: boolean };
export type PrevResult = { prUrl?: string; issueUrls: string[] };

export function buildJudgePrompt(args: {
  thread: ThreadMsg[];
  permalink: string;
  hits: SpecSection[];
  openIssues: Array<{ number: number; title: string; labels: string[] }>;
  areaOptions: string[];
  statusOptions: string[];
  prev?: PrevResult;
}): { prompt: string; outputSchema: object } {
  const thread = args.thread.map((m) => `${m.user}: ${m.text}`).join("\n");
  const specs = args.hits.map((h) => `### ${h.file} — ${h.heading}\n${h.body}`).join("\n\n") || "(검색 결과 없음)";
  const issues = args.openIssues.map((i) => `#${i.number} ${i.title} [${i.labels.join(",")}]`).join("\n") || "(없음)";
  const prevNote = args.prev
    ? `\n\n## 이전 처리 결과 (중복 금지)\n이 스레드는 전에 분석되어 아래가 이미 등록됐다. 같은 내용의 이슈를 새로 만들지 말고, 달라진 부분만 기존 이슈 update나 새 항목으로 판정하라.\n${[args.prev.prUrl && `- 명세 PR: ${args.prev.prUrl}`, ...args.prev.issueUrls.map((u) => `- 이슈: ${u}`)].filter(Boolean).join("\n")}`
    : "";
  const prompt = `Slack 스레드를 분석해 (1) 명세 수정 필요 항목과 (2) GitHub 이슈로 만들거나 갱신할 항목을 판정하라.
합의되지 않은 아이디어 나열·단순 정보 공유는 아무것도 만들지 않는다(nothing_found=true).

## 스레드 (링크: ${args.permalink})
${thread}

## 관련 명세 발췌 (spec_changes.file은 반드시 이 파일명 중에서만)
${specs}

## 현재 열린 이슈 (중복이면 kind=update + number)
${issues}${prevNote}

## 지시
- spec_changes.edit_instruction: 편집자가 파일을 열고 그대로 수행할 수 있게 어느 부분을 어떻게 바꿀지 구체적으로
- issue_actions.title: "feat(app): …" 형식의 한국어 요약, body: 배경·할 일·근거 스레드 링크(${args.permalink}) 포함
- area·status는 제시된 옵션값 중에서만 선택`;
  return {
    prompt,
    outputSchema: {
      type: "object",
      properties: {
        spec_changes: {
          type: "array",
          items: {
            type: "object",
            properties: {
              file: { type: "string" }, summary: { type: "string" },
              rationale: { type: "string" }, edit_instruction: { type: "string" },
            },
            required: ["file", "summary", "rationale", "edit_instruction"],
            additionalProperties: false,
          },
        },
        issue_actions: {
          type: "array",
          items: {
            type: "object",
            properties: {
              kind: { enum: ["create", "update"] }, number: { type: "integer" },
              title: { type: "string" }, body: { type: "string" },
              area: { enum: args.areaOptions }, status: { enum: args.statusOptions },
            },
            required: ["kind", "title", "body", "area", "status"],
            additionalProperties: false,
          },
        },
        nothing_found: { type: "boolean" },
      },
      required: ["spec_changes", "issue_actions", "nothing_found"],
      additionalProperties: false,
    },
  };
}

export function buildEditPrompt(args: { file: string; content: string; instruction: string }): { prompt: string; outputSchema: object } {
  return {
    prompt: `아래 markdown 파일에 편집 지시를 적용하기 위한 문자열 치환 목록을 만들어라.
old는 파일에서 정확히 1번만 등장하는 원문 그대로(공백·개행 포함), new는 치환 결과다.

## 파일: ${args.file}
${args.content}

## 편집 지시
${args.instruction}`,
    outputSchema: {
      type: "object",
      properties: {
        edits: {
          type: "array", minItems: 1,
          items: {
            type: "object",
            properties: { old: { type: "string" }, new: { type: "string" } },
            required: ["old", "new"],
            additionalProperties: false,
          },
        },
      },
      required: ["edits"],
      additionalProperties: false,
    },
  };
}

/** 치환을 결정적으로 적용한다. 매치가 정확히 1건이 아니면 throw (스펙 §4.3). */
export function applyEdits(content: string, edits: Array<{ old: string; new: string }>): string {
  let out = content;
  edits.forEach((e, i) => {
    const count = out.split(e.old).length - 1;
    if (count !== 1) throw new Error(`edits[${i}]: old 문자열 매치 ${count}건 (정확히 1건이어야 함)`);
    out = out.replace(e.old, e.new);
  });
  return out;
}
```

- [ ] **Step 5: 통과 확인**

Run: `cd pm-bot && pnpm vitest run test/analysis.test.ts test/qa.test.ts && pnpm typecheck`
Expected: PASS (analysis 8개 + qa 기존 8개)

- [ ] **Step 6: 커밋**

```bash
git add pm-bot/src/analysis.ts pm-bot/src/adapters/claude.ts pm-bot/src/qa.ts pm-bot/test/analysis.test.ts
git commit -m "feat(pm-bot): 판정·편집 프롬프트와 치환 적용기 — runWithRetry 공용화 (#202)"
```

---

### Task 4: gh 클라이언트 1부 — 인증·이슈·보드 (`src/github.ts`)

**Files:**
- Create: `src/github.ts`
- Test: `test/github.test.ts`

**Interfaces:**
- Consumes: 없음 (독립 모듈 — exec 함수 주입)
- Produces (Task 5가 확장, Task 6·7이 사용):
  ```ts
  export type Exec = (file: string, args: string[], opts?: { cwd?: string }) => Promise<{ stdout: string }>;
  export type OpenIssue = { number: number; title: string; labels: string[] };
  export type GhConfig = { repo: string; projectOwner: string; projectNumber: number; specDirInRepo: string; account?: string; workRepoDir: string };
  export type GhClient = {
    checkAuth(): Promise<{ ok: boolean; login: string }>;
    listOpenIssues(): Promise<OpenIssue[]>;
    createIssue(a: { title: string; body: string }): Promise<{ number: number; url: string }>;
    commentIssue(a: { number: number; body: string }): Promise<{ url: string }>;
    boardOptions(): Promise<{ area: string[]; status: string[] }>;
    setBoardFields(issueNumber: number, fields: { area?: string; status?: string }): Promise<void>;
    // Task 5에서 추가: prepareSpecRepo, readSpecFile, submitSpecPr, mergePr, closePr
  };
  export function createGhClient(cfg: GhConfig, exec: Exec): GhClient;
  ```

- [ ] **Step 1: 실패하는 테스트 작성** — `test/github.test.ts`

```ts
import { describe, expect, it } from "vitest";
import { createGhClient, type Exec } from "../src/github.js";

const CFG = { repo: "o/r", projectOwner: "o", projectNumber: 2, specDirInRepo: "docs/specs", account: "kmjnnhyk", workRepoDir: "/tmp/none" };

/** 명령 프리픽스 → stdout 응답을 등록하고 호출 기록을 남기는 가짜 exec */
function fakeExec(responses: Array<[string, string]>) {
  const calls: string[] = [];
  const exec: Exec = async (file, args) => {
    const cmd = [file, ...args].join(" ");
    calls.push(cmd);
    const hit = responses.find(([prefix]) => cmd.startsWith(prefix));
    if (!hit) throw new Error(`unexpected: ${cmd}`);
    return { stdout: hit[1] };
  };
  return { exec, calls };
}

const BOARD_META = JSON.stringify({
  data: { organization: { projectV2: { id: "P1", fields: { nodes: [
    { id: "F_ST", name: "Status", options: [{ id: "o1", name: "Todo" }, { id: "o2", name: "Done" }] },
    { id: "F_AR", name: "Area", options: [{ id: "a1", name: "S2 홈" }] },
    {},
  ] } } } },
});

describe("createGhClient — 인증·이슈·보드", () => {
  it("checkAuth는 활성 계정이 account와 일치할 때만 ok", async () => {
    const { exec } = fakeExec([["gh api user", "kmjnnhyk\n"]]);
    expect(await createGhClient(CFG, exec).checkAuth()).toEqual({ ok: true, login: "kmjnnhyk" });
    const { exec: e2 } = fakeExec([["gh api user", "jinhyeok-bell\n"]]);
    expect(await createGhClient(CFG, e2).checkAuth()).toEqual({ ok: false, login: "jinhyeok-bell" });
  });

  it("listOpenIssues는 gh issue list JSON을 파싱한다", async () => {
    const { exec, calls } = fakeExec([["gh issue list", JSON.stringify([{ number: 3, title: "t", labels: [{ name: "app" }] }])]]);
    expect(await createGhClient(CFG, exec).listOpenIssues()).toEqual([{ number: 3, title: "t", labels: ["app"] }]);
    expect(calls[0]).toContain("--repo o/r");
    expect(calls[0]).toContain("--state open");
  });

  it("createIssue는 URL에서 번호를 파싱한다", async () => {
    const { exec } = fakeExec([["gh issue create", "https://github.com/o/r/issues/42\n"]]);
    expect(await createGhClient(CFG, exec).createIssue({ title: "t", body: "b" })).toEqual({ number: 42, url: "https://github.com/o/r/issues/42" });
  });

  it("setBoardFields는 아이템 추가 후 필드 2개를 설정한다", async () => {
    const { exec, calls } = fakeExec([
      ["gh api graphql -f query=query", BOARD_META],
      ["gh api repos/o/r/issues/42", "I_node\n"],
      ["gh api graphql -f query=mutation($p: ID!, $c: ID!)", JSON.stringify({ data: { addProjectV2ItemById: { item: { id: "ITEM1" } } } })],
      ["gh api graphql -f query=mutation($p: ID!, $i: ID!", "{}"],
    ]);
    await createGhClient(CFG, exec).setBoardFields(42, { area: "S2 홈", status: "Todo" });
    const mutations = calls.filter((c) => c.includes("updateProjectV2ItemFieldValue"));
    expect(mutations).toHaveLength(2);
    expect(mutations[0]).toContain("a1");
    expect(mutations[1]).toContain("o1");
  });

  it("모르는 area 옵션이면 가용 옵션을 담아 throw", async () => {
    const { exec } = fakeExec([
      ["gh api graphql -f query=query", BOARD_META],
      ["gh api repos/o/r/issues/42", "I_node\n"],
      ["gh api graphql -f query=mutation($p: ID!, $c: ID!)", JSON.stringify({ data: { addProjectV2ItemById: { item: { id: "ITEM1" } } } })],
    ]);
    await expect(createGhClient(CFG, exec).setBoardFields(42, { area: "없는곳" })).rejects.toThrow(/S2 홈/);
  });

  it("boardOptions는 옵션 이름 목록을 준다 (조회는 1회 캐시)", async () => {
    const { exec, calls } = fakeExec([["gh api graphql -f query=query", BOARD_META]]);
    const gh = createGhClient(CFG, exec);
    expect(await gh.boardOptions()).toEqual({ area: ["S2 홈"], status: ["Todo", "Done"] });
    await gh.boardOptions();
    expect(calls).toHaveLength(1);
  });
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd pm-bot && pnpm vitest run test/github.test.ts`
Expected: FAIL — `Cannot find module '../src/github.js'`

- [ ] **Step 3: 구현** — `src/github.ts`

```ts
export type Exec = (file: string, args: string[], opts?: { cwd?: string }) => Promise<{ stdout: string }>;
export type OpenIssue = { number: number; title: string; labels: string[] };
export type GhConfig = {
  repo: string;            // "thumbsup-studio/thumbsup"
  projectOwner: string;    // "thumbsup-studio" (org)
  projectNumber: number;   // Thumbs Up Roadmap = 2
  specDirInRepo: string;   // "docs/specs"
  account?: string;        // 기대 gh 활성 계정 — 불일치 시 GitHub 액션 비활성 (403 함정)
  workRepoDir: string;     // 명세 PR용 blobless clone 절대 경로
};

type BoardMeta = {
  projectId: string;
  area: { fieldId: string; options: Record<string, string> };
  status: { fieldId: string; options: Record<string, string> };
};

const FIELDS_QUERY = `query($owner: String!, $number: Int!) {
  organization(login: $owner) { projectV2(number: $number) {
    id
    fields(first: 30) { nodes { ... on ProjectV2SingleSelectField { id name options { id name } } } }
  } }
}`;
const ADD_ITEM_MUTATION = `mutation($p: ID!, $c: ID!) { addProjectV2ItemById(input: { projectId: $p, contentId: $c }) { item { id } } }`;
const SET_FIELD_MUTATION = `mutation($p: ID!, $i: ID!, $f: ID!, $o: String!) {
  updateProjectV2ItemFieldValue(input: { projectId: $p, itemId: $i, fieldId: $f, value: { singleSelectOptionId: $o } }) { projectV2Item { id } }
}`;

export type GhClient = ReturnType<typeof createGhClient>;

export function createGhClient(cfg: GhConfig, exec: Exec) {
  let boardMeta: BoardMeta | null = null;

  async function gh(args: string[], opts?: { cwd?: string }): Promise<string> {
    return (await exec("gh", args, opts)).stdout.trim();
  }

  async function getBoardMeta(): Promise<BoardMeta> {
    if (boardMeta) return boardMeta;
    const raw = await gh(["api", "graphql", "-f", `query=${FIELDS_QUERY}`, "-f", `owner=${cfg.projectOwner}`, "-F", `number=${cfg.projectNumber}`]);
    const project = JSON.parse(raw).data.organization.projectV2 as {
      id: string;
      fields: { nodes: Array<{ id?: string; name?: string; options?: Array<{ id: string; name: string }> }> };
    };
    const pick = (name: string) => {
      const f = project.fields.nodes.find((n) => n.name === name);
      if (!f?.id || !f.options) throw new Error(`보드 필드 '${name}'를 찾을 수 없습니다`);
      return { fieldId: f.id, options: Object.fromEntries(f.options.map((o) => [o.name, o.id])) };
    };
    boardMeta = { projectId: project.id, area: pick("Area"), status: pick("Status") };
    return boardMeta;
  }

  async function setField(meta: BoardMeta, itemId: string, field: "area" | "status", value: string): Promise<void> {
    const optionId = meta[field].options[value];
    if (!optionId) throw new Error(`보드 ${field} 옵션 '${value}' 없음 — 가용: ${Object.keys(meta[field].options).join(", ")}`);
    await gh(["api", "graphql", "-f", `query=${SET_FIELD_MUTATION}`, "-f", `p=${meta.projectId}`, "-f", `i=${itemId}`, "-f", `f=${meta[field].fieldId}`, "-f", `o=${optionId}`]);
  }

  return {
    async checkAuth(): Promise<{ ok: boolean; login: string }> {
      const login = await gh(["api", "user", "-q", ".login"]);
      return { ok: !cfg.account || login === cfg.account, login };
    },

    async listOpenIssues(): Promise<OpenIssue[]> {
      const raw = await gh(["issue", "list", "--repo", cfg.repo, "--state", "open", "--limit", "200", "--json", "number,title,labels"]);
      return (JSON.parse(raw) as Array<{ number: number; title: string; labels: Array<{ name: string }> }>).map((i) => ({
        number: i.number, title: i.title, labels: i.labels.map((l) => l.name),
      }));
    },

    async createIssue(a: { title: string; body: string }): Promise<{ number: number; url: string }> {
      const url = await gh(["issue", "create", "--repo", cfg.repo, "--title", a.title, "--body", a.body]);
      const number = Number(url.split("/").pop());
      if (!Number.isInteger(number)) throw new Error(`이슈 URL 파싱 실패: ${url}`);
      return { number, url };
    },

    async commentIssue(a: { number: number; body: string }): Promise<{ url: string }> {
      return { url: await gh(["issue", "comment", String(a.number), "--repo", cfg.repo, "--body", a.body]) };
    },

    async boardOptions(): Promise<{ area: string[]; status: string[] }> {
      const meta = await getBoardMeta();
      return { area: Object.keys(meta.area.options), status: Object.keys(meta.status.options) };
    },

    /** 이슈를 보드에 넣고(이미 있으면 기존 아이템 재사용 — addProjectV2ItemById는 멱등) 필드를 설정한다. */
    async setBoardFields(issueNumber: number, fields: { area?: string; status?: string }): Promise<void> {
      const meta = await getBoardMeta();
      const nodeId = await gh(["api", `repos/${cfg.repo}/issues/${issueNumber}`, "-q", ".node_id"]);
      const added = await gh(["api", "graphql", "-f", `query=${ADD_ITEM_MUTATION}`, "-f", `p=${meta.projectId}`, "-f", `c=${nodeId}`]);
      const itemId = JSON.parse(added).data.addProjectV2ItemById.item.id as string;
      if (fields.area) await setField(meta, itemId, "area", fields.area);
      if (fields.status) await setField(meta, itemId, "status", fields.status);
    },
  };
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd pm-bot && pnpm vitest run test/github.test.ts && pnpm typecheck`
Expected: PASS (6개)

- [ ] **Step 5: 커밋**

```bash
git add pm-bot/src/github.ts pm-bot/test/github.test.ts
git commit -m "feat(pm-bot): gh CLI 클라이언트 — 인증·이슈·Roadmap 보드 배치 (#202)"
```

---

### Task 5: gh 클라이언트 2부 — `.workrepo` 명세 PR·머지 (`src/github.ts` 확장)

**Files:**
- Modify: `src/github.ts`
- Test: `test/github.test.ts` (describe 추가)

**Interfaces:**
- Consumes: Task 4의 `createGhClient` 내부 구조
- Produces (Task 6·7이 사용) — 반환 객체에 메서드 추가:
  ```ts
  prepareSpecRepo(): Promise<void>;                       // clone(최초)·fetch·origin/main으로 리셋
  readSpecFile(file: string): Promise<string>;            // specDirInRepo/<file> 내용
  submitSpecPr(a: { branch: string; files: Array<{ file: string; content: string }>; commitMsg: string; title: string; body: string }): Promise<{ number: number; url: string }>;
  mergePr(prNumber: number): Promise<void>;               // --auto --squash
  closePr(prNumber: number, comment: string): Promise<void>;
  ```

- [ ] **Step 1: 실패하는 테스트 작성** — `test/github.test.ts`에 추가

```ts
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

describe("createGhClient — .workrepo 명세 PR", () => {
  function workCfg() {
    const dir = mkdtempSync(join(tmpdir(), "workrepo-"));
    return { ...CFG, workRepoDir: join(dir, "repo") };
  }

  it("prepareSpecRepo는 .git이 없으면 blobless clone부터 한다", async () => {
    const cfg = workCfg();
    const { exec, calls } = fakeExec([["git clone", ""], ["git -C", ""]]);
    await createGhClient(cfg, exec).prepareSpecRepo();
    expect(calls[0]).toBe(`git clone --filter=blob:none https://github.com/o/r.git ${cfg.workRepoDir}`);
    expect(calls[1]).toContain("fetch origin");
    expect(calls[2]).toContain("checkout -f -B main origin/main");
  });

  it("prepareSpecRepo는 clone이 있으면 fetch·리셋만 한다", async () => {
    const cfg = workCfg();
    mkdirSync(join(cfg.workRepoDir, ".git"), { recursive: true });
    const { exec, calls } = fakeExec([["git -C", ""]]);
    await createGhClient(cfg, exec).prepareSpecRepo();
    expect(calls.some((c) => c.startsWith("git clone"))).toBe(false);
    expect(calls).toHaveLength(2);
  });

  it("submitSpecPr는 브랜치·파일 쓰기·커밋·푸시·PR 생성을 순서대로 수행한다", async () => {
    const cfg = workCfg();
    mkdirSync(join(cfg.workRepoDir, "docs/specs"), { recursive: true });
    const { exec, calls } = fakeExec([["git -C", ""], ["gh pr create", "https://github.com/o/r/pull/9\n"]]);
    const res = await createGhClient(cfg, exec).submitSpecPr({
      branch: "docs/pm-bot-1-0", files: [{ file: "spec.md", content: "새 내용" }],
      commitMsg: "docs(spec): x (pm-bot)", title: "docs(spec): x (pm-bot)", body: "근거",
    });
    expect(res).toEqual({ number: 9, url: "https://github.com/o/r/pull/9" });
    expect(readFileSync(join(cfg.workRepoDir, "docs/specs/spec.md"), "utf8")).toBe("새 내용");
    const seq = calls.map((c) => c.split(" ").slice(0, 4).join(" "));
    expect(calls.some((c) => c.includes("checkout -B docs/pm-bot-1-0"))).toBe(true);
    expect(calls.some((c) => c.includes("commit -m"))).toBe(true);
    expect(calls.some((c) => c.includes("push -u origin docs/pm-bot-1-0 --force"))).toBe(true);
    expect(seq[seq.length - 1]).toContain("gh pr create");
  });

  it("readSpecFile은 specDirInRepo 밑에서 읽는다", async () => {
    const cfg = workCfg();
    mkdirSync(join(cfg.workRepoDir, "docs/specs"), { recursive: true });
    writeFileSync(join(cfg.workRepoDir, "docs/specs/a.md"), "본문", "utf8");
    const { exec } = fakeExec([]);
    expect(await createGhClient(cfg, exec).readSpecFile("a.md")).toBe("본문");
  });

  it("mergePr·closePr는 auto-squash·코멘트 클로즈를 호출한다", async () => {
    const { exec, calls } = fakeExec([["gh pr", ""]]);
    const gh = createGhClient(CFG, exec);
    await gh.mergePr(9);
    await gh.closePr(9, "반려");
    expect(calls[0]).toBe("gh pr merge 9 --repo o/r --auto --squash");
    expect(calls[1]).toBe("gh pr close 9 --repo o/r --comment 반려");
  });
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd pm-bot && pnpm vitest run test/github.test.ts`
Expected: FAIL — `prepareSpecRepo is not a function`

- [ ] **Step 3: 구현** — `src/github.ts` 반환 객체에 메서드 추가 (파일 상단에 `import { existsSync } from "node:fs"; import { mkdir, readFile, writeFile } from "node:fs/promises"; import { dirname, join } from "node:path";`)

```ts
async function git(args: string[]): Promise<string> {
  return (await exec("git", ["-C", cfg.workRepoDir, ...args])).stdout.trim();
}
```

```ts
/** 최초엔 blobless clone, 이후엔 fetch + origin/main 강제 리셋 — 잡 간 상태 오염 방지 (스펙 §4.4). */
async prepareSpecRepo(): Promise<void> {
  if (!existsSync(join(cfg.workRepoDir, ".git"))) {
    await exec("git", ["clone", "--filter=blob:none", `https://github.com/${cfg.repo}.git`, cfg.workRepoDir]);
  }
  await git(["fetch", "origin"]);
  await git(["checkout", "-f", "-B", "main", "origin/main"]);
},

async readSpecFile(file: string): Promise<string> {
  return readFile(join(cfg.workRepoDir, cfg.specDirInRepo, file), "utf8");
},

async submitSpecPr(a: { branch: string; files: Array<{ file: string; content: string }>; commitMsg: string; title: string; body: string }): Promise<{ number: number; url: string }> {
  await git(["checkout", "-B", a.branch]);
  for (const f of a.files) {
    const path = join(cfg.workRepoDir, cfg.specDirInRepo, f.file);
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, f.content, "utf8");
  }
  await git(["add", "-A"]);
  await git(["commit", "-m", a.commitMsg]);
  await git(["push", "-u", "origin", a.branch, "--force"]); // 재분석 시 같은 브랜치 재사용
  const url = await gh(["pr", "create", "--repo", cfg.repo, "--head", a.branch, "--title", a.title, "--body", a.body], { cwd: cfg.workRepoDir });
  const number = Number(url.split("/").pop());
  if (!Number.isInteger(number)) throw new Error(`PR URL 파싱 실패: ${url}`);
  return { number, url };
},

async mergePr(prNumber: number): Promise<void> {
  await gh(["pr", "merge", String(prNumber), "--repo", cfg.repo, "--auto", "--squash"]);
},

async closePr(prNumber: number, comment: string): Promise<void> {
  await gh(["pr", "close", String(prNumber), "--repo", cfg.repo, "--comment", comment]);
},
```

- [ ] **Step 4: 통과 확인**

Run: `cd pm-bot && pnpm vitest run test/github.test.ts && pnpm typecheck`
Expected: PASS (11개)

- [ ] **Step 5: 커밋**

```bash
git add pm-bot/src/github.ts pm-bot/test/github.test.ts
git commit -m "feat(pm-bot): .workrepo blobless clone 기반 명세 PR·auto-merge (#202)"
```

---

### Task 6: 스레드 fetch + 분석 drain — `src/analysis.ts` 2부

**Files:**
- Modify: `src/analysis.ts`
- Test: `test/analysis.test.ts` (describe 추가)

**Interfaces:**
- Consumes: Task 1 DB 메서드, Task 3 프롬프트·`runWithRetry`, Task 4·5 `GhClient`, `HistoryClient`(collector.ts — `replies` 재사용), `search`(specindex.ts)
- Produces (Task 7·8이 사용):
  ```ts
  export type FetchedThread = { msgs: ThreadMsg[]; lastMsgTs: string };
  export function fetchThread(client: HistoryClient, channel: string, threadTs: string): Promise<FetchedThread>;
  export type AnalysisDeps = {
    db: PmDb; adapter: CliAdapter; index: SpecSection[]; gh: GhClient | null;
    history: HistoryClient;
    getPermalink(channel: string, ts: string): Promise<string>;
    postMessage(channel: string, threadTs: string, text: string): Promise<{ ts: string }>;
    log(line: string): void;
  };
  export function drainAnalysisQueue(deps: AnalysisDeps): Promise<number>;  // 처리 건수
  ```

- [ ] **Step 1: 실패하는 테스트 작성** — `test/analysis.test.ts`에 추가

```ts
import type { CliAdapter } from "../src/adapters/types.js";
import { openDb } from "../src/db.js";
import { drainAnalysisQueue, fetchThread, type AnalysisDeps } from "../src/analysis.js";
import type { GhClient } from "../src/github.js";

/** 스레드 페이지 응답과 postMessage 기록을 갖춘 테스트 하네스 */
function harness(over: Partial<{ threadMsgs: Array<{ ts: string; user?: string; text?: string }>; judgeJson: object; editJson: object }> = {}) {
  const db = openDb(":memory:");
  const posted: string[] = [];
  const ghCalls: string[] = [];
  const judge = over.judgeJson ?? { spec_changes: [], issue_actions: [], nothing_found: true };
  const adapterOutputs = [JSON.stringify(judge), JSON.stringify(over.editJson ?? { edits: [{ old: "2순위", new: "3순위" }] })];
  let adapterCall = 0;
  const deps: AnalysisDeps = {
    db,
    adapter: { run: async () => adapterOutputs[Math.min(adapterCall++, 1)]! } as CliAdapter,
    index: [{ file: "spec.md", heading: "h", ids: [], body: "북마크는 2순위" }],
    history: {
      history: async () => ({ messages: [] }),
      replies: async ({ channel }) => ({
        messages: (over.threadMsgs ?? [{ ts: "1.0", user: "U1", text: "북마크 미루자" }]).map((m) => ({ channel, ts: m.ts, user: m.user, text: m.text })),
      }),
    },
    gh: {
      listOpenIssues: async () => { ghCalls.push("list"); return []; },
      boardOptions: async () => ({ area: ["S2 홈"], status: ["Todo"] }),
      createIssue: async () => { ghCalls.push("createIssue"); return { number: 42, url: "https://gh/i/42" }; },
      commentIssue: async () => { ghCalls.push("commentIssue"); return { url: "https://gh/i/3#c" }; },
      setBoardFields: async () => { ghCalls.push("setBoardFields"); },
      checkAuth: async () => ({ ok: true, login: "kmjnnhyk" }),
      prepareSpecRepo: async () => { ghCalls.push("prepare"); },
      readSpecFile: async () => "북마크는 2순위",
      submitSpecPr: async () => { ghCalls.push("submitSpecPr"); return { number: 9, url: "https://gh/pr/9" }; },
      mergePr: async () => {}, closePr: async () => {},
    } as GhClient,
    getPermalink: async () => "https://slack/p1",
    postMessage: async (_c, _t, text) => { posted.push(text); return { ts: `bot.${posted.length}` }; },
    log: () => {},
  };
  return { db, deps, posted, ghCalls };
}

describe("fetchThread", () => {
  it("봇 메시지(user 없음)도 포함하고 마지막 ts를 계산한다", async () => {
    const { deps } = harness({ threadMsgs: [{ ts: "1.0", user: "U1", text: "질문" }, { ts: "2.0", text: "AI 허들 요약" }] });
    const t = await fetchThread(deps.history, "C1", "1.0");
    expect(t.msgs).toEqual([{ user: "U1", text: "질문" }, { user: "bot", text: "AI 허들 요약" }]);
    expect(t.lastMsgTs).toBe("2.0");
  });
});

describe("drainAnalysisQueue", () => {
  it("nothing_found면 '찾지 못했다' 답글 후 done", async () => {
    const { db, deps, posted } = harness();
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    expect(await drainAnalysisQueue(deps)).toBe(1);
    expect(posted[0]).toContain("찾지 못했");
    expect(db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" })).toBe("queued"); // done 상태였음
  });

  it("spec_changes는 PR 생성 → 승인 대기 답글 ts를 spec_prs에 기록한다", async () => {
    const { db, deps, posted, ghCalls } = harness({
      judgeJson: { spec_changes: [{ file: "spec.md", summary: "북마크 연기", rationale: "합의", edit_instruction: "2순위를 3순위로" }], issue_actions: [], nothing_found: false },
    });
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    await drainAnalysisQueue(deps);
    expect(ghCalls).toContain("prepare");
    expect(ghCalls).toContain("submitSpecPr");
    expect(posted.some((p) => p.includes("https://gh/pr/9"))).toBe(true);
    // 승인 대기 답글(첫 게시)의 ts로 역참조 가능해야 한다
    expect(db.specPrByMessage("C1", "bot.1")?.prNumber).toBe(9);
  });

  it("issue create는 등록 + 보드 배치 + 사후 보고", async () => {
    const { db, deps, posted, ghCalls } = harness({
      judgeJson: { spec_changes: [], issue_actions: [{ kind: "create", title: "t", body: "b", area: "S2 홈", status: "Todo" }], nothing_found: false },
    });
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    await drainAnalysisQueue(deps);
    expect(ghCalls).toEqual(expect.arrayContaining(["createIssue", "setBoardFields"]));
    expect(posted.some((p) => p.includes("https://gh/i/42"))).toBe(true);
  });

  it("done 재큐잉 + 새 메시지 없음 → '이미 처리됨' 답글만 하고 done 복원", async () => {
    const { db, deps, posted, ghCalls } = harness();
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    db.markAnalysisRunning("C1", "1.0");
    db.markAnalysisDone("C1", "1.0", "1.0", '{"prUrl":"https://gh/pr/9","issueUrls":[]}'); // lastMsgTs = 스레드 마지막과 동일
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U2" });
    await drainAnalysisQueue(deps);
    expect(posted[0]).toContain("이미 처리");
    expect(posted[0]).toContain("https://gh/pr/9");
    expect(ghCalls).not.toContain("list"); // 판정까지 안 감
  });

  it("gh 비활성이면 failed + 안내 답글", async () => {
    const { db, deps, posted } = harness();
    deps.gh = null;
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    await drainAnalysisQueue(deps);
    expect(posted[0]).toContain("GitHub 연동");
    expect(db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" })).toBe("queued"); // failed → 재시도 가능
  });

  it("이슈 단계 실패 시 성공한 PR 링크를 포함해 ⚠️ 보고하고 failed", async () => {
    const { db, deps, posted } = harness({
      judgeJson: {
        spec_changes: [{ file: "spec.md", summary: "s", rationale: "r", edit_instruction: "2순위를 3순위로" }],
        issue_actions: [{ kind: "create", title: "t", body: "b", area: "S2 홈", status: "Todo" }],
        nothing_found: false,
      },
    });
    deps.gh = { ...deps.gh!, createIssue: async () => { throw new Error("boom"); } };
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    await drainAnalysisQueue(deps);
    const warn = posted.find((p) => p.includes("⚠️"))!;
    expect(warn).toContain("boom");
    expect(warn).toContain("https://gh/pr/9");
  });
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd pm-bot && pnpm vitest run test/analysis.test.ts`
Expected: FAIL — `fetchThread is not a function` 등

- [ ] **Step 3: 구현** — `src/analysis.ts`에 추가 (import: `runWithRetry`(adapters/claude.js), `search`·`SpecSection`(specindex.js), `HistoryClient`(collector.js), `PmDb`(db.js), `GhClient`(github.js), `CliAdapter`(adapters/types.js))

```ts
export type FetchedThread = { msgs: ThreadMsg[]; lastMsgTs: string };

/** 스레드 전문을 실시간 조회한다. user 없는 봇 메시지(허들 AI 노트)도 포함 — 스펙 §2. */
export async function fetchThread(client: HistoryClient, channel: string, threadTs: string): Promise<FetchedThread> {
  const msgs: ThreadMsg[] = [];
  let lastMsgTs = threadTs;
  let cursor: string | undefined;
  do {
    const page = await client.replies({ channel, ts: threadTs, cursor });
    for (const m of page.messages) {
      if (!m.text) continue;
      msgs.push({ user: m.user ?? "bot", text: m.text });
      if (Number(m.ts) > Number(lastMsgTs)) lastMsgTs = m.ts;
    }
    cursor = page.nextCursor;
  } while (cursor);
  return { msgs, lastMsgTs };
}

export type AnalysisDeps = {
  db: PmDb;
  adapter: CliAdapter;
  index: SpecSection[];
  gh: GhClient | null;
  history: HistoryClient;
  getPermalink(channel: string, ts: string): Promise<string>;
  postMessage(channel: string, threadTs: string, text: string): Promise<{ ts: string }>;
  log(line: string): void;
};

function prevLinks(prev: PrevResult): string {
  return [prev.prUrl && `\n• 명세 PR: ${prev.prUrl}`, ...prev.issueUrls.map((u) => `\n• 이슈: ${u}`)].filter(Boolean).join("");
}

/** pending 분석을 순차 처리한다. 실패는 failed로 남기고 스레드에 알린다 (조용한 실패 금지). */
export async function drainAnalysisQueue(deps: AnalysisDeps): Promise<number> {
  let handled = 0;
  for (let job = deps.db.nextPendingAnalysis(); job !== null; job = deps.db.nextPendingAnalysis()) {
    deps.db.markAnalysisRunning(job.channel, job.threadTs);
    const done: string[] = []; // 부분 성공 추적 — catch에서 보고에 포함
    const result: PrevResult = { issueUrls: [] };
    try {
      if (!deps.gh) throw new Error("GitHub 연동 비활성 상태예요 (gh 계정·config.github 확인)");
      const gh = deps.gh;
      const { msgs, lastMsgTs } = await fetchThread(deps.history, job.channel, job.threadTs);
      const prev = job.resultJson ? (JSON.parse(job.resultJson) as PrevResult) : undefined;
      if (prev && job.lastMsgTs === lastMsgTs) {
        await deps.postMessage(job.channel, job.threadTs, `🤖 이미 처리한 스레드예요 (새 메시지 없음).${prevLinks(prev)}`);
        deps.db.markAnalysisDone(job.channel, job.threadTs, lastMsgTs, job.resultJson!);
        handled += 1;
        continue;
      }
      const permalink = await deps.getPermalink(job.channel, job.threadTs);
      const options = await gh.boardOptions();
      const openIssues = await gh.listOpenIssues();
      const hits = search(deps.index, msgs.map((m) => m.text).join(" ").slice(0, 2000));
      const judgeRaw = await runWithRetry(deps.adapter, buildJudgePrompt({ thread: msgs, permalink, hits, openIssues, areaOptions: options.area, statusOptions: options.status, prev }), { onLog: deps.log });
      const judge = JSON.parse(judgeRaw) as JudgeResult;

      if (judge.spec_changes.length > 0) {
        await gh.prepareSpecRepo();
        const files: Array<{ file: string; content: string }> = [];
        for (const c of judge.spec_changes) {
          const content = await gh.readSpecFile(c.file);
          const editRaw = await runWithRetry(deps.adapter, buildEditPrompt({ file: c.file, content, instruction: c.edit_instruction }), { onLog: deps.log });
          files.push({ file: c.file, content: applyEdits(content, (JSON.parse(editRaw) as { edits: Array<{ old: string; new: string }> }).edits) });
        }
        const summary = judge.spec_changes.map((c) => c.summary).join(", ");
        const pr = await gh.submitSpecPr({
          branch: `docs/pm-bot-${job.threadTs.replace(".", "-")}`,
          files,
          commitMsg: `docs(spec): ${summary} (pm-bot)`,
          title: `docs(spec): ${summary} (pm-bot)`,
          body: `근거 스레드: ${permalink}\n\n${judge.spec_changes.map((c) => `- ${c.summary}: ${c.rationale}`).join("\n")}`,
        });
        result.prUrl = pr.url;
        done.push(`명세 PR: ${pr.url}`);
        const posted = await deps.postMessage(job.channel, job.threadTs, `📝 명세 변경 제안: ${pr.url}\n이 메시지에 ✅ 반응 → 자동 머지, ❌ → 반려`);
        deps.db.insertSpecPr({ prNumber: pr.number, prUrl: pr.url, channel: job.channel, messageTs: posted.ts, threadTs: job.threadTs, status: "awaiting" });
      }

      for (const a of judge.issue_actions) {
        if (a.kind === "create") {
          const issue = await gh.createIssue({ title: a.title, body: `${a.body}\n\n근거 스레드: ${permalink}` });
          await gh.setBoardFields(issue.number, { area: a.area, status: a.status });
          result.issueUrls.push(issue.url);
          done.push(`이슈 생성: ${issue.url}`);
        } else {
          if (a.number == null) throw new Error(`issue_actions update에 number 없음: ${a.title}`);
          const c = await gh.commentIssue({ number: a.number, body: `${a.body}\n\n근거 스레드: ${permalink}` });
          await gh.setBoardFields(a.number, { status: a.status });
          result.issueUrls.push(c.url);
          done.push(`이슈 갱신: #${a.number}`);
        }
      }

      if (done.length === 0) {
        await deps.postMessage(job.channel, job.threadTs, "🤖 분석했지만 명세 변경·이슈로 등록할 내용을 찾지 못했어요.");
      } else {
        await deps.postMessage(job.channel, job.threadTs, `🤖 분석 완료:\n${done.map((d) => `• ${d}`).join("\n")}`);
      }
      deps.db.markAnalysisDone(job.channel, job.threadTs, lastMsgTs, JSON.stringify(result));
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      deps.db.markAnalysisFailed(job.channel, job.threadTs, msg);
      const partial = done.length > 0 ? `\n완료된 항목:\n${done.map((d) => `• ${d}`).join("\n")}` : "";
      try {
        await deps.postMessage(job.channel, job.threadTs, `⚠️ 분석 처리에 실패했어요: ${msg}${partial}\n🤖를 다시 달면 재시도해요.`);
      } catch (postErr) {
        deps.log(`실패 알림 게시 실패 (${job.channel}/${job.threadTs}): ${postErr instanceof Error ? postErr.message : String(postErr)}`);
      }
    }
    handled += 1;
  }
  return handled;
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd pm-bot && pnpm vitest run test/analysis.test.ts && pnpm typecheck`
Expected: PASS (1부 8개 + 2부 7개)

- [ ] **Step 5: 커밋**

```bash
git add pm-bot/src/analysis.ts pm-bot/test/analysis.test.ts
git commit -m "feat(pm-bot): 실시간 스레드 fetch·분석 drain — 멱등 재트리거·부분 실패 보고 (#202)"
```

---

### Task 7: 배선 — config·index.ts·매니페스트·gitignore

**Files:**
- Modify: `src/config.ts`, `src/index.ts`, `slack-app-manifest.yml`, `.gitignore`, `pm-bot.config.example.json`
- Test: `test/config.test.ts` (it 추가)

**Interfaces:**
- Consumes: Task 1·2·4·5·6의 모든 export, 기존 `createClaudeAdapter`·`buildIndex`·drain 패턴
- Produces: `PmConfig.github?: { repo: string; projectOwner: string; projectNumber: number; specDirInRepo: string; account?: string }` (Task 8 dryrun이 사용)

- [ ] **Step 1: config 실패 테스트 작성** — `test/config.test.ts`에 추가

```ts
it("github 블록이 있으면 필수 키를 검증한다", () => {
  const base = { channels: ["C1"], dbPath: "./db", specDir: "./specs" };
  expect(() => loadConfig({ ...base, github: { repo: "o/r" } })).toThrow(/github/);
  const ok = loadConfig({ ...base, github: { repo: "o/r", projectOwner: "o", projectNumber: 2, specDirInRepo: "docs/x", account: "kmjnnhyk" } });
  expect(ok.github?.projectNumber).toBe(2);
});

it("github 블록이 없으면 undefined로 통과한다 (Phase 1 설정 호환)", () => {
  expect(loadConfig({ channels: ["C1"], dbPath: "./db", specDir: "./specs" }).github).toBeUndefined();
});
```

- [ ] **Step 2: 실패 확인 후 config 구현**

Run: `cd pm-bot && pnpm vitest run test/config.test.ts` → FAIL 확인. `src/config.ts`:

```ts
export type GithubConfig = { repo: string; projectOwner: string; projectNumber: number; specDirInRepo: string; account?: string };
export type PmConfig = {
  channels: string[];
  dbPath: string;
  specDir: string;
  claudeBin?: string;
  /** 없으면 GitHub 액션(명세 PR·이슈) 비활성 — 수집·Q&A만 동작 */
  github?: GithubConfig;
};
```

`loadConfig`에 검증 추가 (기존 missing 패턴):

```ts
let github: GithubConfig | undefined;
if (r.github !== undefined) {
  const g = r.github as Record<string, unknown>;
  if (typeof r.github !== "object" || r.github === null) missing.push("github(객체)");
  else if (typeof g.repo !== "string" || typeof g.projectOwner !== "string" || typeof g.projectNumber !== "number" || typeof g.specDirInRepo !== "string")
    missing.push("github.repo/projectOwner/projectNumber/specDirInRepo");
  else github = { repo: g.repo, projectOwner: g.projectOwner, projectNumber: g.projectNumber, specDirInRepo: g.specDirInRepo, account: typeof g.account === "string" ? g.account : undefined };
}
```

반환 객체에 `github` 추가. Run: `pnpm vitest run test/config.test.ts` → PASS.

- [ ] **Step 3: index.ts 배선** — 추가/변경 지점만 (기존 코드는 그대로 둔다)

import 추가:

```ts
import { resolve } from "node:path";
import { execa } from "execa";
import { drainAnalysisQueue, ANALYSIS_SYSTEM_PROMPT } from "./analysis.js";
import { createGhClient, type GhClient } from "./github.js";
import { routeReaction, type ReactionEvent } from "./reactions.js";
```

어댑터·gh 초기화 (기존 `adapter` 선언 아래):

```ts
const analysisAdapter = createClaudeAdapter({ bin: cfg.claudeBin, systemPrompt: ANALYSIS_SYSTEM_PROMPT });

let gh: GhClient | null = null;
if (cfg.github) {
  const client = createGhClient(
    { ...cfg.github, workRepoDir: resolve("./.workrepo") },
    (file, args, opts) => execa(file, args, { ...opts, timeout: 120_000 }),
  );
  const auth = await client.checkAuth().catch((e) => ({ ok: false, login: e instanceof Error ? e.message : String(e) }));
  if (auth.ok) gh = client;
  else console.warn(`[pm-bot] gh 활성 계정 불일치/오류(${auth.login}) — GitHub 액션 비활성 (gh auth switch 필요)`);
} else {
  console.warn("[pm-bot] config.github 없음 — GitHub 액션 비활성");
}
```

봇 user ID (app.start 전, `snapshotCursors` 위):

```ts
const botUserId = ((await app.client.auth.test()).user_id ?? "") as string;
```

분석 drain 루프 (qa `drain()` 아래 — 같은 재진입 가드 패턴):

```ts
let analysisDraining = false;
let analysisRequested = false;
async function drainAnalysis(): Promise<void> {
  if (analysisDraining) {
    analysisRequested = true;
    return;
  }
  analysisDraining = true;
  try {
    do {
      analysisRequested = false;
      await drainAnalysisQueue({
        db,
        adapter: analysisAdapter,
        index,
        gh,
        history: historyClient(),
        getPermalink: async (channel, ts) => {
          const res = await app.client.chat.getPermalink({ channel, message_ts: ts });
          return res.permalink ?? `slack://${channel}/${ts}`;
        },
        postMessage: async (channel, threadTs, text) => {
          const res = await app.client.chat.postMessage({ channel, thread_ts: threadTs, text });
          return { ts: (res.ts ?? "") as string };
        },
        log: (line) => console.log(`[analysis] ${line}`),
      });
    } while (analysisRequested);
  } finally {
    analysisDraining = false;
  }
}
```

reaction_added 핸들러 (`app_mention` 핸들러 아래):

```ts
app.event("reaction_added", async ({ event }) => {
  const ev = event as unknown as ReactionEvent;
  const route = routeReaction(ev, { botUserId, channels: cfg.channels, specPrByMessage: (c, t) => db.specPrByMessage(c, t) });
  if (route.kind === "ignore") return;

  if (route.kind === "trigger") {
    // 이모지가 달린 메시지의 스레드 부모를 찾는다 (스펙 §4.1)
    const res = await app.client.conversations.replies({ channel: route.channel, ts: route.ts, limit: 1 });
    const threadTs = (res.messages?.[0] as { thread_ts?: string } | undefined)?.thread_ts ?? route.ts;
    if (db.requestAnalysis({ channel: route.channel, threadTs, requestedBy: route.user }) === "queued") {
      await app.client.reactions.add({ channel: route.channel, timestamp: route.ts, name: "eyes" }).catch(() => {});
      void drainAnalysis();
    }
    return;
  }

  // approve | reject — 승인 대기 답글에 달린 ✅/❌
  const reply = (text: string) => app.client.chat.postMessage({ channel: route.pr.channel, thread_ts: route.pr.threadTs, text });
  if (!gh) {
    await reply("⚠️ GitHub 연동이 비활성이라 PR을 처리할 수 없어요.");
    return;
  }
  try {
    if (route.kind === "approve") {
      await gh.mergePr(route.pr.prNumber);
      db.markSpecPr(route.pr.prNumber, "approved");
      await reply(`✅ 승인 — CI 통과 후 자동 머지됩니다: ${route.pr.prUrl}`);
    } else {
      await gh.closePr(route.pr.prNumber, "PM봇: Slack ❌ 반려");
      db.markSpecPr(route.pr.prNumber, "rejected");
      await reply("❌ 반려 — PR을 닫았어요. 정정 내용을 이 스레드에 남겨주세요.");
    }
  } catch (err) {
    await reply(`⚠️ PR 처리 실패: ${err instanceof Error ? err.message : String(err)}`).catch(() => {});
  }
});
```

부팅 시퀀스 (기존 백필 블록에 추가):

```ts
const resetCount = db.resetRunningAnalyses();
if (resetCount > 0) console.log(`[pm-bot] 중단됐던 분석 ${resetCount}건 재큐잉`);
```

파일 끝 `await drain();` 아래에 `await drainAnalysis();` 추가.

- [ ] **Step 4: 매니페스트·gitignore·example config**

`slack-app-manifest.yml` — scopes에 `reactions:write`(reactions:read 아래), bot_events에 `reaction_added` 추가:

```yaml
      - reactions:read
      - reactions:write
```

```yaml
    bot_events:
      - app_mention
      - message.channels
      - reaction_added
```

`.gitignore` 끝에 추가:

```
.workrepo/
```

`pm-bot.config.example.json` 전체:

```json
{
  "channels": ["C0PLANNING", "C0DEV"],
  "dbPath": "./pm-bot.sqlite",
  "specDir": "../docs/product",
  "github": {
    "repo": "thumbsup-studio/thumbsup",
    "projectOwner": "thumbsup-studio",
    "projectNumber": 2,
    "specDirInRepo": "docs/specs",
    "account": "kmjnnhyk"
  }
}
```

- [ ] **Step 5: 전체 게이트 + 기동 스모크**

Run: `cd pm-bot && pnpm typecheck && pnpm test`
Expected: 전체 PASS

기동 스모크(운영 봇이 떠 있으면 **먼저 내리지 말 것** — 같은 앱 토큰 중복 기동 금지, SKILL.md 함정. 운영 봇이 꺼진 상태에서만):

```bash
cd pm-bot && timeout 30 pnpm start
```
Expected: `Socket Mode 연결됨` + `백필 완료` + (config.github 있으면) gh 경고 없음. `reaction_added` 미구독 상태라 이모지는 아직 안 들어옴 — 정상 (재설치는 Task 10).

- [ ] **Step 6: 커밋**

```bash
git add pm-bot/src/config.ts pm-bot/src/index.ts pm-bot/slack-app-manifest.yml pm-bot/.gitignore pm-bot/pm-bot.config.example.json pm-bot/test/config.test.ts
git commit -m "feat(pm-bot): reaction_added 배선 — 트리거·승인 핸들러·gh 초기화 (#202)"
```

---

### Task 8: `analyze-dryrun.ts` 하네스 (+ `@slack/web-api` 의존성)

**Files:**
- Create: `analyze-dryrun.ts` (pm-bot 루트 — qa-dryrun.ts 옆)
- Modify: `package.json` (의존성 추가)

**Interfaces:**
- Consumes: `fetchThread`·`buildJudgePrompt`·`buildEditPrompt`·`applyEdits`(analysis.ts), `createGhClient`(github.ts — 읽기 전용 호출만), `search`·`buildIndex`(specindex.ts), `readConfigFile`(config.ts), `createClaudeAdapter`·`runWithRetry`(adapters)
- Produces: 없음 (운영자용 CLI)

- [ ] **Step 1: 의존성 추가**

```bash
cd pm-bot && pnpm add @slack/web-api
```

(bolt의 전이 의존성이지만 pnpm 격리 구조상 직접 선언해야 import 가능. **워크트리는 격리 install이므로 main 레포에 leak 없음** — lockfile 변경은 이 브랜치 커밋에 포함)

- [ ] **Step 2: 구현** — `analyze-dryrun.ts` (파일 전체)

```ts
// Slack 이벤트·DB·gh 실행 없이 분석 품질만 본다: fetch → 판정 → (--edit 시) 편집 diff 미리보기.
// 사용법: pnpm tsx --env-file-if-exists=.env analyze-dryrun.ts <channel> <thread_ts> [--edit]
import { WebClient } from "@slack/web-api";
import { createClaudeAdapter, runWithRetry } from "./src/adapters/claude.js";
import { ANALYSIS_SYSTEM_PROMPT, applyEdits, buildEditPrompt, buildJudgePrompt, fetchThread, type JudgeResult } from "./src/analysis.js";
import { readConfigFile } from "./src/config.js";
import { createGhClient } from "./src/github.js";
import { buildIndex, search } from "./src/specindex.js";
import type { HistoryClient, SlackMessage } from "./src/collector.js";
import { execa } from "execa";
import { readFileSync } from "node:fs";
import { join, resolve } from "node:path";

const [channel, threadTs] = process.argv.slice(2);
const wantEdit = process.argv.includes("--edit");
if (!channel || !threadTs) {
  console.error("사용법: pnpm tsx analyze-dryrun.ts <channel> <thread_ts> [--edit]");
  process.exit(1);
}

const cfg = readConfigFile(process.env.PM_BOT_CONFIG ?? "./pm-bot.config.json");
if (!cfg.github) {
  console.error("config.github 필요 (열린 이슈·보드 옵션 조회용 — 읽기 전용)");
  process.exit(1);
}
const slack = new WebClient(process.env.SLACK_BOT_TOKEN);
const history: HistoryClient = {
  async history() {
    return { messages: [] };
  },
  async replies({ channel, ts, cursor }) {
    const res = await slack.conversations.replies({ channel, ts, cursor, limit: 200 });
    return {
      messages: (res.messages ?? []).map((m) => ({ ...m, channel }) as SlackMessage),
      nextCursor: res.response_metadata?.next_cursor || undefined,
    };
  },
};
const gh = createGhClient({ ...cfg.github, workRepoDir: resolve("./.workrepo") }, (file, args, opts) => execa(file, args, opts));
const adapter = createClaudeAdapter({ bin: cfg.claudeBin, systemPrompt: ANALYSIS_SYSTEM_PROMPT });

const { msgs, lastMsgTs } = await fetchThread(history, channel, threadTs);
console.log(`## 스레드 ${msgs.length}건 (마지막 ts ${lastMsgTs})`);
for (const m of msgs) console.log(`  ${m.user}: ${m.text.slice(0, 80)}`);

const index = buildIndex(cfg.specDir);
const hits = search(index, msgs.map((m) => m.text).join(" ").slice(0, 2000));
console.log(`\n## 명세 히트 ${hits.length}건: ${hits.map((h) => `${h.file}#${h.heading}`).join(", ")}`);

const options = await gh.boardOptions();
const openIssues = await gh.listOpenIssues();
const permalink = (await slack.chat.getPermalink({ channel, message_ts: threadTs })).permalink ?? "(permalink 실패)";
const judgeRaw = await runWithRetry(
  adapter,
  buildJudgePrompt({ thread: msgs, permalink, hits, openIssues, areaOptions: options.area, statusOptions: options.status }),
  { onLog: (l) => console.error(`[claude] ${l}`) },
);
const judge = JSON.parse(judgeRaw) as JudgeResult;
console.log("\n## 판정\n" + JSON.stringify(judge, null, 2));

if (wantEdit) {
  for (const c of judge.spec_changes) {
    // dryrun은 .workrepo 대신 로컬 specDir을 읽는다 (읽기 전용)
    const content = readFileSync(join(cfg.specDir, c.file), "utf8");
    const editRaw = await runWithRetry(adapter, buildEditPrompt({ file: c.file, content, instruction: c.edit_instruction }), { onLog: (l) => console.error(`[claude] ${l}`) });
    const { edits } = JSON.parse(editRaw) as { edits: Array<{ old: string; new: string }> };
    console.log(`\n## 편집 미리보기 — ${c.file}`);
    for (const e of edits) console.log(`--- old\n${e.old}\n+++ new\n${e.new}`);
    applyEdits(content, edits); // 매치 검증만 (결과 미저장)
    console.log("(치환 검증 통과)");
  }
}
```

- [ ] **Step 3: 검증**

Run: `cd pm-bot && pnpm typecheck && pnpm test`
Expected: PASS (dryrun은 실행 안 함 — 실 데이터 검증은 Task 10 e2e 직전에 운영자가 수행)

- [ ] **Step 4: 커밋**

```bash
git add pm-bot/analyze-dryrun.ts pm-bot/package.json pm-bot/pnpm-lock.yaml
git commit -m "feat(pm-bot): analyze-dryrun 하네스 — Slack·gh 실행 없이 분석 품질 검증 (#202)"
```

---

### Task 9: 문서 — SKILL.md·CONTRIBUTING

**Files:**
- Modify: `.claude/skills/pm-bot/SKILL.md`, `CONTRIBUTING.md` (레포 루트)

**Interfaces:** 없음 (문서)

- [ ] **Step 1: SKILL.md 갱신**

frontmatter `description`에 트리거 문구 추가: 기존 문구 끝에 `, "스레드 분석", "이모지 트리거", "명세 PR 승인"` 류를 포함하도록 확장. 본문 수정:

1. 첫 문단의 "Phase 1은 **읽기 전용**" → Phase 2 기능 반영으로 교체:

```markdown
지정한 Slack 채널의 대화를 로컬 SQLite에 모으고, 멘션하면 레포의 명세 markdown을 근거로 답하는 상주 봇. Phase 2부터 스레드에 🤖 이모지를 달면 스레드를 분석해 **명세 수정 PR**(✅ 승인 시 자동 머지)과 **GitHub 이슈 등록·갱신**(Thumbs Up Roadmap 보드 배치)까지 수행한다.
```

2. "사용법" 섹션에 추가:

```markdown
### 🤖 스레드 분석 (Phase 2)

분석하고 싶은 스레드의 아무 메시지에 🤖(robot_face) 반응을 단다. 채널 멤버 누구나 가능.

- 접수되면 봇이 👀를 달고, 완료되면 스레드에 결과(명세 PR·이슈 링크)를 답글로 남긴다
- 명세 변경은 봇이 올린 "📝 명세 변경 제안" 답글에 ✅를 달면 auto-merge, ❌면 PR 클로즈
- 같은 스레드에 🤖를 다시 달면: 새 메시지가 없으면 "이미 처리됨", 있으면 재분석(기존 이슈는 중복 생성 대신 갱신)
- 실패하면 ⚠️ 답글이 남는다 — 🤖를 다시 달면 재시도
- 비용: 분석 1건당 claude 호출 2회+ ≈ $0.15~0.25 (운영자 구독)
```

3. "Phase 0 셋업" 섹션에 재설치 절차 추가:

```markdown
### 5. Phase 2 업그레이드 — 앱 재설치 (최초 1회)

매니페스트에 `reaction_added` 이벤트·`reactions:write` 스코프가 추가됐다. 기존 앱에 반영하려면:

1. https://api.slack.com/apps → 앱 선택 → **App Manifest** → `pm-bot/slack-app-manifest.yml` 내용으로 교체 → Save
2. 스코프가 바뀌었으므로 **Reinstall to Workspace** 버튼이 뜬다 → 재설치 (토큰은 그대로 유효)
3. 봇 재기동 후 테스트 채널 스레드에 🤖를 달아 👀가 달리는지 확인
```

4. config 예시의 `github` 블록 설명 추가 (Task 7의 example과 동일 JSON + "없으면 GitHub 액션 비활성, 수집·Q&A만 동작" 한 줄), "함정" 섹션에 gh 계정 항목 추가:

```markdown
### gh 활성 계정이 jinhyeok-bell이면 GitHub 액션이 꺼진다

기동 로그에 `gh 활성 계정 불일치` 경고가 뜨면 명세 PR·이슈 생성이 비활성 상태다(수집·Q&A는 정상).
`gh auth switch --user kmjnnhyk` 후 재기동.
```

5. "DB 들여다보기"에 추가: `sqlite3 pm-bot.sqlite "select thread_ts, status, error from analyses"` / `"select pr_number, status from spec_prs"`. "Slack 없이 답변 품질만 보기" 아래에 analyze-dryrun 사용법 한 단락(Task 8 사용법 주석과 동일 명령).

- [ ] **Step 2: CONTRIBUTING.md에 봇 커밋 규약 예외 추가**

`grep -n "커밋" CONTRIBUTING.md`로 커밋 컨벤션 섹션을 찾아 그 끝에 1줄 추가 (스펙 §4.4, 원 설계 §4-4):

```markdown
> 예외: PM 봇(pm-bot)이 자동 생성하는 명세 PR은 이슈 연결 없이 `docs(spec): <요약> (pm-bot)` 형식을 사용한다.
```

- [ ] **Step 3: 커밋**

```bash
git add .claude/skills/pm-bot/SKILL.md CONTRIBUTING.md
git commit -m "docs(pm-bot): Phase 2 운영법 — 🤖 사용법·앱 재설치·봇 PR 규약 예외 (#202)"
```

---

### Task 10: 전체 게이트 + 실 Slack e2e (운영자 협업 — 수동 게이트)

**Files:** 없음 (검증만. 발견된 버그는 이 태스크에서 수정 커밋)

- [ ] **Step 1: 전체 게이트**

```bash
cd pm-bot && pnpm typecheck && pnpm test
```
Expected: 전체 PASS. 실패 시 수정 후 재실행 (subagent 클레임 신뢰 금지 — 메인 세션이 직접 재실행).

- [ ] **Step 2: 앱 재설치** (운영자 수동 — SKILL.md의 "Phase 2 업그레이드" 절차 그대로)

- [ ] **Step 3: dryrun으로 분석 품질 선검증** (e2e 전 필수)

```bash
cd pm-bot && pnpm tsx --env-file-if-exists=.env analyze-dryrun.ts <테스트채널ID> <기존 스레드 ts> --edit
```
확인: 스레드 fetch에 봇 메시지(허들 AI 노트) 포함 여부, 판정 JSON의 file·area·status 유효성, 편집 치환 검증 통과. **AI 노트의 text가 비어 있으면(blocks 전용 메시지) 여기서 드러난다** — 그 경우 fetchThread에 blocks 텍스트 추출을 추가하는 후속 수정 필요.

- [ ] **Step 4: 실 Slack e2e** (테스트 채널, 봇 기동 상태)

| # | 시나리오 | 기대 결과 |
|---|---|---|
| 1 | 팀원 텍스트 스레드에 🤖 | 👀 → 분석 답글(명세 PR 링크 또는 이슈 링크 또는 "찾지 못했어요") |
| 2 | 명세 PR 제안 답글에 ✅ | `gh pr view`로 auto-merge 활성 확인, CI 통과 후 머지 |
| 3 | 이슈 생성 케이스 | 이슈가 Thumbs Up Roadmap 보드에 Area·Status 채워져 노출 |
| 4 | 허들 AI 요약 노트 스레드에 🤖 | 봇 메시지 본문이 분석에 포함됨 (실시간 fetch 경로) |
| 5 | 같은 스레드에 🤖 재반응 (새 메시지 없이) | "이미 처리한 스레드예요" + 기존 링크 |
| 6 | ❌ 반려 | PR 클로즈 + "정정 내용을 남겨주세요" 답글 |

- [ ] **Step 5: e2e에서 나온 수정사항 커밋 후 최종 게이트 재실행**

```bash
cd pm-bot && pnpm typecheck && pnpm test
```

- [ ] **Step 6: PR 생성** — `pr` 스킬 사용. 본문 `Refs #202` (**Closes 금지** — #202는 Phase 4까지 열어둠). 푸시 전 `gh auth status`로 kmjnnhyk 계정 확인.

---

## 태스크 의존 그래프

```
Task 1 (DB) ──┬─▶ Task 2 (라우터) ──┐
              │                     │
Task 3 (프롬프트·runWithRetry) ──┐  │
                                 ├──┼─▶ Task 6 (drain) ─▶ Task 7 (배선) ─▶ Task 8 (dryrun) ─▶ Task 10 (e2e)
Task 4 (gh 이슈·보드) ─▶ Task 5 ─┘  │                                          ▲
                                    └──────────────────────▶ Task 9 (문서) ────┘ (9는 7 이후 아무 때나)
```

Task 1·2·3·4는 상호 독립 — 병렬 dispatch 가능.
