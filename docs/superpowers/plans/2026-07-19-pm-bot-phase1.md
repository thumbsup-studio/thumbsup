# PM 봇 Phase 1 (수집·백필·Q&A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Slack 지정 채널을 수집·백필하고, @멘션 질문에 명세(markdown) 근거로 답하는 읽기 전용 PM 봇을 만든다.

**Architecture:** 단일 Node 상주 프로세스. Bolt(Socket Mode)가 이벤트를 받아 SQLite에 적재하고, 기동 시 `conversations.history`로 공백을 백필한다. Q&A는 "멘션 → `qa_pending` 큐 → 순차 drain(명세 인덱스 검색 → `claude -p` 답변 생성 → 스레드 게시)" 단일 경로로 실시간·백필을 동일 처리한다. LLM 호출은 `bridge/src/adapters/`의 claude 어댑터를 이식해 사용한다.

**Tech Stack:** TypeScript / Node ≥22 (ESM), `@slack/bolt` v4(Socket Mode), `better-sqlite3`, `execa`(claude CLI spawn), `tsx`(실행), `vitest`(테스트)

**스펙:** `docs/superpowers/specs/2026-07-19-pm-bot-design.md` §3.1(수집기·Q&A)·§5·§6 — Phase 2(분석→PR→승인)·Phase 3(이슈·리포트)·Phase 4(pm-mcp)는 **후속 플랜**이며 이 플랜 범위가 아니다.

## Global Constraints

- Node `>=22`, `"type": "module"` — 로컬 import는 반드시 `.js` 확장자 (`import ... from "./config.js"`)
- `pm-bot/`은 bridge 전례를 따라 **독립 pnpm 패키지** (레포 루트 workspace 아님) — 의존성 작업은 `pm-bot/` 안에서 `pnpm ...`
- 구현 브랜치: `feat/202-pm-bot-phase1` (워크트리 `~/DEV/thumbsup__worktrees/feat-202-pm-bot-phase1`, main 직접 커밋 금지)
- 커밋 형식: `<type>(pm-bot): <한국어 요약> (#202)` — 커밋 생성 시 `commit` 스킬 로드
- claude 어댑터의 CLI 플래그 세트(`--tools "" --strict-mcp-config --setting-sources "" --disable-slash-commands`)와 `BLOCKED_ENV_KEYS` env 격리는 **변경 금지** (개인 구독 보호·환경 미상속 전제)
- `.env`(Slack 토큰)·`pm-bot.config.json`·`*.sqlite`는 커밋 금지 — Task 1에서 `.gitignore` 등록
- 게이트: `pnpm typecheck`(tsc --noEmit) + `pnpm test`(vitest run) 통과 후 커밋

## File Structure

```
pm-bot/
  package.json  tsconfig.json  .gitignore  .env.example  pm-bot.config.example.json
  src/
    config.ts        # 설정 로드·검증 (채널·경로)
    db.ts            # SQLite 스키마 + 쿼리 (messages, qa_pending)
    collector.ts     # 이벤트 적재 + 백필 (history/replies 페이지네이션)
    specindex.ts     # 명세 markdown 섹션 인덱스 + 검색 (ID 우선, 키워드 폴백)
    qa.ts            # Q&A 프롬프트 조립 + 큐 drain
    index.ts         # 부팅: config → db → Bolt(Socket Mode) → backfill → drain
    adapters/        # bridge에서 이식: claude.ts, spawn.ts, types.ts
  test/
    config.test.ts  db.test.ts  collector.test.ts  specindex.test.ts  qa.test.ts
```

---

### Task 1: 패키지 스캐폴드 + config 로더

**Files:**
- Create: `pm-bot/package.json`, `pm-bot/tsconfig.json`, `pm-bot/.gitignore`, `pm-bot/.env.example`, `pm-bot/pm-bot.config.example.json`, `pm-bot/src/config.ts`
- Test: `pm-bot/test/config.test.ts`

**Interfaces:**
- Produces: `type PmConfig = { channels: string[]; dbPath: string; specDir: string; claudeBin?: string }`, `loadConfig(raw: unknown): PmConfig` (검증 실패 시 누락 키를 담은 Error throw), `readConfigFile(path: string): PmConfig`

- [ ] **Step 1: 스캐폴드 파일 작성**

`pm-bot/package.json`:

```json
{
  "name": "thumbsup-pm-bot",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "engines": { "node": ">=22" },
  "packageManager": "pnpm@10.11.0",
  "scripts": {
    "start": "tsx src/index.ts",
    "test": "vitest run",
    "test:watch": "vitest",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@slack/bolt": "^4.2.0",
    "better-sqlite3": "^12.2.0",
    "execa": "^9.6.0"
  },
  "devDependencies": {
    "@types/better-sqlite3": "^7.6.13",
    "@types/node": "^22",
    "tsx": "^4.23.0",
    "typescript": "^5",
    "vitest": "^3.2.4"
  }
}
```

`pm-bot/tsconfig.json` (bridge와 동일 계열):

```json
{
  "compilerOptions": {
    "target": "ES2023",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "skipLibCheck": true,
    "noEmit": true,
    "types": ["node"]
  },
  "include": ["src/**/*.ts", "test/**/*.ts"]
}
```

`pm-bot/.gitignore`:

```
node_modules/
.env
pm-bot.config.json
*.sqlite
*.sqlite-journal
```

`pm-bot/.env.example`:

```
SLACK_BOT_TOKEN=xoxb-...
SLACK_APP_TOKEN=xapp-...
```

`pm-bot/pm-bot.config.example.json`:

```json
{
  "channels": ["C0PLANNING", "C0DEV"],
  "dbPath": "./pm-bot.sqlite",
  "specDir": "../docs/product"
}
```

- [ ] **Step 2: 실패하는 테스트 작성** — `pm-bot/test/config.test.ts`

```ts
import { describe, expect, it } from "vitest";
import { loadConfig } from "../src/config.js";

describe("loadConfig", () => {
  it("유효한 설정을 그대로 반환한다", () => {
    const cfg = loadConfig({ channels: ["C1"], dbPath: "./x.sqlite", specDir: "./docs" });
    expect(cfg.channels).toEqual(["C1"]);
    expect(cfg.claudeBin).toBeUndefined();
  });

  it("channels가 비어 있으면 키 이름을 담아 던진다", () => {
    expect(() => loadConfig({ channels: [], dbPath: "./x", specDir: "./d" })).toThrow(/channels/);
  });

  it("dbPath·specDir 누락 시 던진다", () => {
    expect(() => loadConfig({ channels: ["C1"] })).toThrow(/dbPath|specDir/);
  });

  it("객체가 아니면 던진다", () => {
    expect(() => loadConfig(null)).toThrow();
  });
});
```

- [ ] **Step 3: 실패 확인**

Run: `cd pm-bot && pnpm install && pnpm test`
Expected: FAIL — `Cannot find module '../src/config.js'`

- [ ] **Step 4: 구현** — `pm-bot/src/config.ts`

```ts
import { readFileSync } from "node:fs";

export type PmConfig = {
  /** 수집 대상 Slack 채널 ID 목록 (스펙 §2 "지정 채널만") */
  channels: string[];
  dbPath: string;
  /** 명세 markdown 루트 (병합된 스프린트 문서) */
  specDir: string;
  claudeBin?: string;
};

export function loadConfig(raw: unknown): PmConfig {
  if (typeof raw !== "object" || raw === null) throw new Error("설정은 JSON 객체여야 합니다.");
  const r = raw as Record<string, unknown>;
  const missing: string[] = [];
  if (!Array.isArray(r.channels) || r.channels.length === 0 || !r.channels.every((c) => typeof c === "string"))
    missing.push("channels(비어 있지 않은 문자열 배열)");
  if (typeof r.dbPath !== "string" || r.dbPath === "") missing.push("dbPath");
  if (typeof r.specDir !== "string" || r.specDir === "") missing.push("specDir");
  if (missing.length > 0) throw new Error(`pm-bot 설정 누락/오류: ${missing.join(", ")}`);
  return {
    channels: r.channels as string[],
    dbPath: r.dbPath as string,
    specDir: r.specDir as string,
    claudeBin: typeof r.claudeBin === "string" ? r.claudeBin : undefined,
  };
}

export function readConfigFile(path: string): PmConfig {
  return loadConfig(JSON.parse(readFileSync(path, "utf8")));
}
```

- [ ] **Step 5: 통과 확인**

Run: `pnpm test && pnpm typecheck`
Expected: PASS (4 tests)

- [ ] **Step 6: 커밋** — `commit` 스킬 로드 후

```bash
git add pm-bot/
git commit -m "feat(pm-bot): 패키지 스캐폴드 + 설정 로더 (#202)"
```

---

### Task 2: SQLite 저장소 (messages · qa_pending)

**Files:**
- Create: `pm-bot/src/db.ts`
- Test: `pm-bot/test/db.test.ts`

**Interfaces:**
- Consumes: 없음 (독립)
- Produces:
  - `openDb(path: string): PmDb` — `":memory:"` 지원, 생성 시 스키마 마이그레이션
  - `type MessageRow = { channel: string; ts: string; threadTs: string | null; user: string; text: string }`
  - `PmDb.upsertMessage(m: MessageRow): void` / `PmDb.lastSeenTs(channel: string): string | null` / `PmDb.threadMessages(channel: string, threadTs: string): MessageRow[]`
  - `PmDb.enqueueQa(q: { channel: string; ts: string; user: string; text: string }): boolean` — `(channel, ts)` 중복이면 false (백필 재중복 방지)
  - `PmDb.nextPendingQa(): QaRow | null` / `PmDb.markQaDone(id: number): void` / `PmDb.markQaFailed(id: number, error: string): void`
  - `type QaRow = { id: number; channel: string; ts: string; user: string; text: string }`
  - `PmDb.close(): void`

- [ ] **Step 1: 실패하는 테스트 작성** — `pm-bot/test/db.test.ts`

```ts
import { describe, expect, it } from "vitest";
import { openDb } from "../src/db.js";

function memDb() {
  return openDb(":memory:");
}

describe("messages", () => {
  it("upsert는 같은 (channel, ts)를 덮어쓴다", () => {
    const db = memDb();
    db.upsertMessage({ channel: "C1", ts: "1.0", threadTs: null, user: "U1", text: "a" });
    db.upsertMessage({ channel: "C1", ts: "1.0", threadTs: null, user: "U1", text: "수정됨" });
    expect(db.threadMessages("C1", "1.0")[0]?.text).toBe("수정됨");
  });

  it("lastSeenTs는 채널별 최대 ts를 반환한다", () => {
    const db = memDb();
    expect(db.lastSeenTs("C1")).toBeNull();
    db.upsertMessage({ channel: "C1", ts: "1.0", threadTs: null, user: "U1", text: "a" });
    db.upsertMessage({ channel: "C1", ts: "2.0", threadTs: null, user: "U1", text: "b" });
    db.upsertMessage({ channel: "C2", ts: "9.0", threadTs: null, user: "U1", text: "c" });
    expect(db.lastSeenTs("C1")).toBe("2.0");
  });

  it("threadMessages는 부모+답글을 ts순으로 반환한다", () => {
    const db = memDb();
    db.upsertMessage({ channel: "C1", ts: "1.0", threadTs: null, user: "U1", text: "부모" });
    db.upsertMessage({ channel: "C1", ts: "3.0", threadTs: "1.0", user: "U2", text: "답2" });
    db.upsertMessage({ channel: "C1", ts: "2.0", threadTs: "1.0", user: "U2", text: "답1" });
    expect(db.threadMessages("C1", "1.0").map((m) => m.text)).toEqual(["부모", "답1", "답2"]);
  });
});

describe("qa_pending", () => {
  it("enqueue는 중복 (channel, ts)에 false를 반환한다", () => {
    const db = memDb();
    expect(db.enqueueQa({ channel: "C1", ts: "1.0", user: "U1", text: "q" })).toBe(true);
    expect(db.enqueueQa({ channel: "C1", ts: "1.0", user: "U1", text: "q" })).toBe(false);
  });

  it("nextPendingQa → markQaDone 흐름", () => {
    const db = memDb();
    db.enqueueQa({ channel: "C1", ts: "1.0", user: "U1", text: "q1" });
    db.enqueueQa({ channel: "C1", ts: "2.0", user: "U1", text: "q2" });
    const first = db.nextPendingQa();
    expect(first?.text).toBe("q1");
    db.markQaDone(first!.id);
    expect(db.nextPendingQa()?.text).toBe("q2");
  });

  it("markQaFailed 후에는 다시 뽑히지 않는다 (조용한 무한 재시도 금지)", () => {
    const db = memDb();
    db.enqueueQa({ channel: "C1", ts: "1.0", user: "U1", text: "q" });
    const row = db.nextPendingQa()!;
    db.markQaFailed(row.id, "claude 실패");
    expect(db.nextPendingQa()).toBeNull();
  });
});
```

- [ ] **Step 2: 실패 확인**

Run: `pnpm test`
Expected: FAIL — `Cannot find module '../src/db.js'`

- [ ] **Step 3: 구현** — `pm-bot/src/db.ts`

```ts
import Database from "better-sqlite3";

export type MessageRow = { channel: string; ts: string; threadTs: string | null; user: string; text: string };
export type QaRow = { id: number; channel: string; ts: string; user: string; text: string };
export type PmDb = ReturnType<typeof openDb>;

const SCHEMA = `
CREATE TABLE IF NOT EXISTS messages (
  channel   TEXT NOT NULL,
  ts        TEXT NOT NULL,
  thread_ts TEXT,
  user      TEXT NOT NULL,
  text      TEXT NOT NULL,
  PRIMARY KEY (channel, ts)
);
CREATE INDEX IF NOT EXISTS idx_messages_thread ON messages (channel, thread_ts);
CREATE TABLE IF NOT EXISTS qa_pending (
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  channel TEXT NOT NULL,
  ts      TEXT NOT NULL,
  user    TEXT NOT NULL,
  text    TEXT NOT NULL,
  status  TEXT NOT NULL DEFAULT 'pending',
  error   TEXT,
  UNIQUE (channel, ts)
);
`;

export function openDb(path: string) {
  const db = new Database(path);
  db.pragma("journal_mode = WAL");
  db.exec(SCHEMA);

  const upsertStmt = db.prepare(
    `INSERT INTO messages (channel, ts, thread_ts, user, text) VALUES (@channel, @ts, @threadTs, @user, @text)
     ON CONFLICT (channel, ts) DO UPDATE SET thread_ts = @threadTs, user = @user, text = @text`,
  );
  const lastSeenStmt = db.prepare(`SELECT MAX(CAST(ts AS REAL)) AS m FROM messages WHERE channel = ?`);
  const threadStmt = db.prepare(
    `SELECT channel, ts, thread_ts AS threadTs, user, text FROM messages
     WHERE channel = ? AND (ts = ? OR thread_ts = ?) ORDER BY CAST(ts AS REAL)`,
  );
  const enqueueStmt = db.prepare(
    `INSERT OR IGNORE INTO qa_pending (channel, ts, user, text) VALUES (@channel, @ts, @user, @text)`,
  );
  const nextQaStmt = db.prepare(
    `SELECT id, channel, ts, user, text FROM qa_pending WHERE status = 'pending' ORDER BY id LIMIT 1`,
  );
  const doneStmt = db.prepare(`UPDATE qa_pending SET status = 'done' WHERE id = ?`);
  const failStmt = db.prepare(`UPDATE qa_pending SET status = 'failed', error = ? WHERE id = ?`);
  const maxTsStmt = db.prepare(`SELECT ts FROM messages WHERE channel = ? ORDER BY CAST(ts AS REAL) DESC LIMIT 1`);

  return {
    upsertMessage(m: MessageRow): void {
      upsertStmt.run(m);
    },
    lastSeenTs(channel: string): string | null {
      const row = maxTsStmt.get(channel) as { ts: string } | undefined;
      void lastSeenStmt; // CAST 정렬은 maxTsStmt가 담당
      return row?.ts ?? null;
    },
    threadMessages(channel: string, threadTs: string): MessageRow[] {
      return threadStmt.all(channel, threadTs, threadTs) as MessageRow[];
    },
    enqueueQa(q: { channel: string; ts: string; user: string; text: string }): boolean {
      return enqueueStmt.run(q).changes > 0;
    },
    nextPendingQa(): QaRow | null {
      return (nextQaStmt.get() as QaRow | undefined) ?? null;
    },
    markQaDone(id: number): void {
      doneStmt.run(id);
    },
    markQaFailed(id: number, error: string): void {
      failStmt.run(error, id);
    },
    close(): void {
      db.close();
    },
  };
}
```

주의: `lastSeenStmt`는 사용하지 않으므로 구현 시 삭제하고 `maxTsStmt`만 남길 것 (위 코드는 diff 최소화를 위한 표기이며 최종본에는 미사용 문이 없어야 한다).

- [ ] **Step 4: 통과 확인**

Run: `pnpm test && pnpm typecheck`
Expected: PASS (config 4 + db 6)

- [ ] **Step 5: 커밋**

```bash
git add pm-bot/src/db.ts pm-bot/test/db.test.ts
git commit -m "feat(pm-bot): SQLite 저장소 — messages·qa_pending (#202)"
```

---

### Task 3: 수집기 — 이벤트 적재 + 백필

**Files:**
- Create: `pm-bot/src/collector.ts`
- Test: `pm-bot/test/collector.test.ts`

**Interfaces:**
- Consumes: Task 2의 `PmDb`
- Produces:
  - `type SlackMessage = { channel: string; ts: string; thread_ts?: string; user?: string; text?: string; subtype?: string; reply_count?: number }`
  - `handleMessage(db: PmDb, ev: SlackMessage): void` — subtype 있는 이벤트(수정·삭제·봇 시스템 메시지)와 user 없는 이벤트는 무시
  - `type HistoryClient = { history(params: { channel: string; oldest?: string; cursor?: string }): Promise<HistoryPage>; replies(params: { channel: string; ts: string; cursor?: string }): Promise<HistoryPage> }` / `type HistoryPage = { messages: SlackMessage[]; nextCursor?: string }`
  - `backfill(db: PmDb, client: HistoryClient, channels: string[]): Promise<number>` — 채널별 `lastSeenTs` 이후를 페이지네이션 수집, `reply_count > 0`인 메시지는 replies로 스레드 전체 upsert. 반환값 = 새로 저장한 메시지 수

- [ ] **Step 1: 실패하는 테스트 작성** — `pm-bot/test/collector.test.ts`

```ts
import { describe, expect, it } from "vitest";
import { openDb } from "../src/db.js";
import { backfill, handleMessage, type HistoryClient, type SlackMessage } from "../src/collector.js";

describe("handleMessage", () => {
  it("일반 메시지를 저장한다", () => {
    const db = openDb(":memory:");
    handleMessage(db, { channel: "C1", ts: "1.0", user: "U1", text: "안녕" });
    expect(db.threadMessages("C1", "1.0")).toHaveLength(1);
  });

  it("subtype 이벤트·user 없는 이벤트는 무시한다", () => {
    const db = openDb(":memory:");
    handleMessage(db, { channel: "C1", ts: "1.0", user: "U1", text: "x", subtype: "message_changed" });
    handleMessage(db, { channel: "C1", ts: "2.0", text: "봇" });
    expect(db.lastSeenTs("C1")).toBeNull();
  });
});

function fakeClient(pages: Record<string, SlackMessage[][]>, replies: Record<string, SlackMessage[]> = {}): HistoryClient {
  return {
    async history({ channel, cursor }) {
      const idx = cursor ? Number(cursor) : 0;
      const chunk = pages[channel]?.[idx] ?? [];
      const next = pages[channel] && idx + 1 < pages[channel].length ? String(idx + 1) : undefined;
      return { messages: chunk, nextCursor: next };
    },
    async replies({ ts }) {
      return { messages: replies[ts] ?? [] };
    },
  };
}

describe("backfill", () => {
  it("페이지네이션을 따라가며 저장하고 개수를 반환한다", async () => {
    const db = openDb(":memory:");
    const client = fakeClient({
      C1: [
        [{ channel: "C1", ts: "1.0", user: "U1", text: "a" }],
        [{ channel: "C1", ts: "2.0", user: "U1", text: "b" }],
      ],
    });
    expect(await backfill(db, client, ["C1"])).toBe(2);
    expect(db.lastSeenTs("C1")).toBe("2.0");
  });

  it("reply_count 있는 메시지는 스레드 답글까지 저장한다", async () => {
    const db = openDb(":memory:");
    const client = fakeClient(
      { C1: [[{ channel: "C1", ts: "1.0", user: "U1", text: "부모", reply_count: 1 }]] },
      { "1.0": [{ channel: "C1", ts: "1.5", thread_ts: "1.0", user: "U2", text: "답글" }] },
    );
    await backfill(db, client, ["C1"]);
    expect(db.threadMessages("C1", "1.0").map((m) => m.text)).toEqual(["부모", "답글"]);
  });

  it("lastSeenTs를 oldest로 넘겨 증분 수집한다", async () => {
    const db = openDb(":memory:");
    db.upsertMessage({ channel: "C1", ts: "5.0", threadTs: null, user: "U1", text: "기존" });
    let seenOldest: string | undefined;
    const client: HistoryClient = {
      async history({ oldest }) {
        seenOldest = oldest;
        return { messages: [] };
      },
      async replies() {
        return { messages: [] };
      },
    };
    await backfill(db, client, ["C1"]);
    expect(seenOldest).toBe("5.0");
  });
});
```

- [ ] **Step 2: 실패 확인**

Run: `pnpm test`
Expected: FAIL — `Cannot find module '../src/collector.js'`

- [ ] **Step 3: 구현** — `pm-bot/src/collector.ts`

```ts
import type { PmDb } from "./db.js";

export type SlackMessage = {
  channel: string;
  ts: string;
  thread_ts?: string;
  user?: string;
  text?: string;
  subtype?: string;
  reply_count?: number;
};

export type HistoryPage = { messages: SlackMessage[]; nextCursor?: string };
export type HistoryClient = {
  history(params: { channel: string; oldest?: string; cursor?: string }): Promise<HistoryPage>;
  replies(params: { channel: string; ts: string; cursor?: string }): Promise<HistoryPage>;
};

/** 수정·삭제·시스템 메시지(subtype 존재)와 user 없는 이벤트는 수집하지 않는다. */
export function handleMessage(db: PmDb, ev: SlackMessage): void {
  if (ev.subtype || !ev.user || !ev.text) return;
  db.upsertMessage({ channel: ev.channel, ts: ev.ts, threadTs: ev.thread_ts ?? null, user: ev.user, text: ev.text });
}

async function drainPages(
  fetch: (cursor?: string) => Promise<HistoryPage>,
  onMessage: (m: SlackMessage) => void,
): Promise<void> {
  let cursor: string | undefined;
  do {
    const page = await fetch(cursor);
    for (const m of page.messages) onMessage(m);
    cursor = page.nextCursor;
  } while (cursor);
}

/** 채널별 마지막 저장 ts 이후를 수집한다. 반환 = 새로 저장된 메시지 수. */
export async function backfill(db: PmDb, client: HistoryClient, channels: string[]): Promise<number> {
  let saved = 0;
  for (const channel of channels) {
    const oldest = db.lastSeenTs(channel) ?? undefined;
    const threadParents: SlackMessage[] = [];
    await drainPages(
      (cursor) => client.history({ channel, oldest, cursor }),
      (m) => {
        if (m.subtype || !m.user || !m.text) return;
        db.upsertMessage({ channel, ts: m.ts, threadTs: m.thread_ts ?? null, user: m.user, text: m.text });
        saved += 1;
        if ((m.reply_count ?? 0) > 0) threadParents.push(m);
      },
    );
    for (const parent of threadParents) {
      await drainPages(
        (cursor) => client.replies({ channel, ts: parent.ts, cursor }),
        (m) => {
          if (m.subtype || !m.user || !m.text || m.ts === parent.ts) return;
          db.upsertMessage({ channel, ts: m.ts, threadTs: m.thread_ts ?? parent.ts, user: m.user, text: m.text });
          saved += 1;
        },
      );
    }
  }
  return saved;
}
```

- [ ] **Step 4: 통과 확인**

Run: `pnpm test && pnpm typecheck`
Expected: PASS (누적 15 tests)

- [ ] **Step 5: 커밋**

```bash
git add pm-bot/src/collector.ts pm-bot/test/collector.test.ts
git commit -m "feat(pm-bot): 수집기 — 이벤트 적재·증분 백필 (#202)"
```

---

### Task 4: claude 어댑터 이식 (bridge → pm-bot)

**Files:**
- Create: `pm-bot/src/adapters/types.ts`, `pm-bot/src/adapters/spawn.ts`, `pm-bot/src/adapters/claude.ts`
- Test: `pm-bot/test/adapters.test.ts`
- 원본 참조: `bridge/src/adapters/{types,spawn,claude}.ts` — 로직 동일 이식, bridge 쪽은 **수정하지 않는다**

**Interfaces:**
- Consumes: 없음
- Produces:
  - `type AdapterInput = { prompt: string; outputSchema: unknown }` / `type AdapterHooks = { onLog: (line: string) => void }`
  - `type CliAdapter = { run(input: AdapterInput, hooks: AdapterHooks): Promise<string> }` — 반환 = JSON 문자열
  - `createClaudeAdapter(opts?: { bin?: string; systemPrompt?: string }): CliAdapter` — bridge와의 유일한 차이: 시스템 프롬프트 주입 가능(기본값은 bridge와 동일한 최소 프롬프트)
  - `sanitizedEnv(base?: NodeJS.ProcessEnv): NodeJS.ProcessEnv`, `stripFences(text: string): string`

- [ ] **Step 1: types.ts / spawn.ts 이식**

`pm-bot/src/adapters/types.ts` — bridge 원본에서 `BridgeCli` 의존만 제거:

```ts
export type AdapterInput = { prompt: string; outputSchema: unknown };
export type AdapterHooks = { onLog: (line: string) => void };

/** CLI 어댑터. run() 반환값 = JSON 문자열 (파싱 가능성만 보장, 깊은 검증은 호출부 책임). */
export type CliAdapter = {
  run(input: AdapterInput, hooks: AdapterHooks): Promise<string>;
};
```

`pm-bot/src/adapters/spawn.ts` — bridge 원본 그대로 복사 (`BLOCKED_ENV_KEYS`, `sanitizedEnv`, `stripFences`). 파일 상단 주석에 `bridge/src/adapters/spawn.ts에서 이식 — 구독 보호 로직 변경 금지` 한 줄을 남긴다.

- [ ] **Step 2: 실패하는 테스트 작성** — `pm-bot/test/adapters.test.ts`

```ts
import { describe, expect, it } from "vitest";
import { sanitizedEnv, stripFences } from "../src/adapters/spawn.js";
import { createClaudeAdapter } from "../src/adapters/claude.js";

describe("sanitizedEnv", () => {
  it("API 키를 제거한 복사본을 반환한다", () => {
    const env = sanitizedEnv({ PATH: "/bin", ANTHROPIC_API_KEY: "sk-x", OPENAI_API_KEY: "sk-y" });
    expect(env.PATH).toBe("/bin");
    expect(env.ANTHROPIC_API_KEY).toBeUndefined();
    expect(env.OPENAI_API_KEY).toBeUndefined();
  });
});

describe("stripFences", () => {
  it("json 코드펜스를 벗긴다", () => {
    expect(stripFences('```json\n{"a":1}\n```')).toBe('{"a":1}');
    expect(stripFences('{"a":1}')).toBe('{"a":1}');
  });
});

describe("createClaudeAdapter", () => {
  it("존재하지 않는 바이너리는 stderr 꼬리를 담아 던진다", async () => {
    const adapter = createClaudeAdapter({ bin: "/nonexistent/claude-bin" });
    await expect(
      adapter.run({ prompt: "hi", outputSchema: { type: "object" } }, { onLog: () => {} }),
    ).rejects.toThrow(/claude 실행 실패/);
  });
});
```

- [ ] **Step 3: 실패 확인**

Run: `pnpm test`
Expected: FAIL — `Cannot find module '../src/adapters/spawn.js'`

- [ ] **Step 4: claude.ts 이식** — `pm-bot/src/adapters/claude.ts`

bridge 원본을 복사한 뒤 다음 두 가지만 변경한다.

1. `CliAdapter` import를 로컬 `./types.js`로, `cli: "CLAUDE"` 필드는 제거 (pm-bot은 claude 단일 CLI)
2. 시스템 프롬프트 파라미터화:

```ts
const MINIMAL_SYSTEM_PROMPT = "너는 요청받은 JSON만 출력하는 생성기다.";

export function createClaudeAdapter(opts: { bin?: string; systemPrompt?: string } = {}): CliAdapter {
  return {
    async run({ prompt, outputSchema }, { onLog }) {
      const subprocess = execa(
        opts.bin ?? "claude",
        [
          "-p",
          prompt,
          "--output-format",
          "stream-json",
          "--verbose",
          "--json-schema",
          JSON.stringify(outputSchema),
          "--tools",
          "",
          "--strict-mcp-config",
          "--setting-sources",
          "",
          "--disable-slash-commands",
          "--system-prompt",
          opts.systemPrompt ?? MINIMAL_SYSTEM_PROMPT,
        ],
        { cwd: tmpdir(), env: sanitizedEnv(), extendEnv: false, reject: false, buffer: false, stdin: "ignore" },
      );
      // 이하 stream-json 파싱·result 추출·exitCode 검사·JSON.parse 확인은 bridge 원본과 동일하게 복사
    },
  };
}
```

에러 처리(ENOENT 포함)는 bridge 원본의 `exitCode !== 0 || result === null → throw new Error(\`claude 실행 실패 (exit ...)\`)` 경로가 그대로 담당한다. execa `reject: false`에서 spawn 실패 시 `exitCode`가 undefined이므로 같은 throw로 떨어진다.

- [ ] **Step 5: 통과 확인**

Run: `pnpm test && pnpm typecheck`
Expected: PASS (누적 19 tests)

- [ ] **Step 6: 커밋**

```bash
git add pm-bot/src/adapters/ pm-bot/test/adapters.test.ts
git commit -m "feat(pm-bot): bridge claude 어댑터 이식 — 시스템 프롬프트 주입 지원 (#202)"
```

---

### Task 5: 명세 인덱스 + Q&A 프롬프트·drain

**Files:**
- Create: `pm-bot/src/specindex.ts`, `pm-bot/src/qa.ts`
- Test: `pm-bot/test/specindex.test.ts`, `pm-bot/test/qa.test.ts`

**Interfaces:**
- Consumes: Task 2 `PmDb`(`nextPendingQa`·`markQaDone`·`markQaFailed`·`threadMessages`), Task 4 `CliAdapter`
- Produces:
  - `type SpecSection = { file: string; heading: string; ids: string[]; body: string }`
  - `buildIndex(specDir: string): SpecSection[]` — `*.md`를 `##`/`###` 헤딩 단위로 분해, 본문·헤딩에서 `F-xx`·`P-xx`·`W-xx`·`H-xx`·`Q-xx`·`PG-xx`·`#nn` ID 추출
  - `search(index: SpecSection[], query: string, limit?: number): SpecSection[]` — 질문 속 ID 정확 매치 최우선, 그 외 2자 이상 토큰 겹침 수로 정렬
  - `buildQaPrompt(question: string, hits: SpecSection[]): { prompt: string; outputSchema: object }` — 출력 스키마 `{ answer: string, sources: string[] }`
  - `type QaDeps = { db: PmDb; adapter: CliAdapter; index: SpecSection[]; postMessage(channel: string, threadTs: string, text: string): Promise<void>; log(line: string): void }`
  - `drainQaQueue(deps: QaDeps): Promise<number>` — pending을 순차 처리, 성공 시 답변 게시+done, 실패 시 failed 마킹+스레드에 실패 알림(스펙 §5 조용한 실패 금지). 반환 = 처리 건수

- [ ] **Step 1: 실패하는 테스트 작성** — `pm-bot/test/specindex.test.ts`

```ts
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { buildIndex, search } from "../src/specindex.js";

function specDir(): string {
  const dir = mkdtempSync(join(tmpdir(), "spec-"));
  writeFileSync(
    join(dir, "14_priority.md"),
    "# 우선순위\n\n## 2순위\n\n- F-45 북마크: 히스토리 탭에서 문제 보관 (#36)\n\n## 3순위\n\n- F-17 Codex 정리장\n",
  );
  writeFileSync(join(dir, "10_features.md"), "# 기능\n\n## 저장 계열\n\nF-45는 북마크 기능이다. PG-08 참고.\n");
  return dir;
}

describe("buildIndex", () => {
  it("헤딩 단위로 나누고 ID를 추출한다", () => {
    const index = buildIndex(specDir());
    const sec = index.find((s) => s.heading === "2순위");
    expect(sec?.ids).toContain("F-45");
    expect(sec?.ids).toContain("#36");
  });
});

describe("search", () => {
  it("질문 속 ID가 있으면 해당 섹션이 최상위", () => {
    const index = buildIndex(specDir());
    const hits = search(index, "F-45 스펙이 뭐야?");
    expect(hits.length).toBeGreaterThanOrEqual(2);
    expect(hits[0]!.ids).toContain("F-45");
  });

  it("ID가 없으면 키워드 겹침으로 찾는다", () => {
    const index = buildIndex(specDir());
    expect(search(index, "북마크 어떻게 되지")[0]!.body).toContain("북마크");
  });
});
```

`pm-bot/test/qa.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { openDb } from "../src/db.js";
import { buildQaPrompt, drainQaQueue } from "../src/qa.js";
import type { SpecSection } from "../src/specindex.js";

const SECTIONS: SpecSection[] = [
  { file: "14_priority.md", heading: "2순위", ids: ["F-45"], body: "F-45 북마크 …" },
];

describe("buildQaPrompt", () => {
  it("질문과 명세 발췌를 포함하고 sources 스키마를 요구한다", () => {
    const { prompt, outputSchema } = buildQaPrompt("F-45 뭐야?", SECTIONS);
    expect(prompt).toContain("F-45 뭐야?");
    expect(prompt).toContain("14_priority.md");
    expect(JSON.stringify(outputSchema)).toContain("sources");
  });
});

describe("drainQaQueue", () => {
  it("pending을 답변·게시하고 done 처리한다", async () => {
    const db = openDb(":memory:");
    db.enqueueQa({ channel: "C1", ts: "1.0", user: "U1", text: "<@BOT> F-45 뭐야?" });
    const posted: string[] = [];
    const n = await drainQaQueue({
      db,
      index: SECTIONS,
      adapter: { run: async () => JSON.stringify({ answer: "북마크 기능입니다", sources: ["14_priority.md"] }) },
      postMessage: async (_c, _t, text) => void posted.push(text),
      log: () => {},
    });
    expect(n).toBe(1);
    expect(posted[0]).toContain("북마크 기능입니다");
    expect(db.nextPendingQa()).toBeNull();
  });

  it("어댑터 실패 시 failed 마킹 + 실패 알림을 게시한다", async () => {
    const db = openDb(":memory:");
    db.enqueueQa({ channel: "C1", ts: "1.0", user: "U1", text: "질문" });
    const posted: string[] = [];
    await drainQaQueue({
      db,
      index: SECTIONS,
      adapter: { run: async () => { throw new Error("claude 실행 실패"); } },
      postMessage: async (_c, _t, text) => void posted.push(text),
      log: () => {},
    });
    expect(db.nextPendingQa()).toBeNull();
    expect(posted[0]).toContain("실패");
  });
});
```

- [ ] **Step 2: 실패 확인**

Run: `pnpm test`
Expected: FAIL — `Cannot find module '../src/specindex.js'`

- [ ] **Step 3: specindex.ts 구현**

```ts
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

export type SpecSection = { file: string; heading: string; ids: string[]; body: string };

const ID_RE = /\b(?:[FPWHQ]|PG)-\d{2}\b|#\d{1,4}\b/g;

export function buildIndex(specDir: string): SpecSection[] {
  const sections: SpecSection[] = [];
  for (const name of readdirSync(specDir).filter((f) => f.endsWith(".md")).sort()) {
    const lines = readFileSync(join(specDir, name), "utf8").split("\n");
    let heading = name;
    let body: string[] = [];
    const flush = () => {
      const text = body.join("\n").trim();
      if (text) sections.push({ file: name, heading, ids: [...new Set(`${heading}\n${text}`.match(ID_RE) ?? [])], body: text });
    };
    for (const line of lines) {
      const h = line.match(/^#{2,3}\s+(.+)/);
      if (h) {
        flush();
        heading = h[1]!.trim();
        body = [];
      } else body.push(line);
    }
    flush();
  }
  return sections;
}

export function search(index: SpecSection[], query: string, limit = 5): SpecSection[] {
  const queryIds = new Set(query.match(ID_RE) ?? []);
  const tokens = query.split(/[\s?.,!·]+/).filter((t) => t.length >= 2);
  const scored = index.map((s) => {
    const idScore = [...queryIds].filter((id) => s.ids.includes(id)).length * 100;
    const tokenScore = tokens.filter((t) => s.body.includes(t) || s.heading.includes(t)).length;
    return { s, score: idScore + tokenScore };
  });
  return scored.filter((x) => x.score > 0).sort((a, b) => b.score - a.score).slice(0, limit).map((x) => x.s);
}
```

- [ ] **Step 4: qa.ts 구현**

```ts
import type { CliAdapter } from "./adapters/types.js";
import type { PmDb } from "./db.js";
import { search, type SpecSection } from "./specindex.js";

const QA_SYSTEM_PROMPT =
  "너는 떰즈업 팀의 PM 어시스턴트다. 제공된 명세 발췌만 근거로 한국어로 답하고, 근거가 없으면 모른다고 답한다.";

export function buildQaPrompt(question: string, hits: SpecSection[]): { prompt: string; outputSchema: object } {
  const context = hits
    .map((h) => `### ${h.file} — ${h.heading}\n${h.body}`)
    .join("\n\n");
  return {
    prompt: `다음 명세 발췌를 근거로 질문에 답하라.\n\n## 명세 발췌\n${context || "(검색 결과 없음)"}\n\n## 질문\n${question}`,
    outputSchema: {
      type: "object",
      properties: {
        answer: { type: "string", description: "질문에 대한 한국어 답변" },
        sources: { type: "array", items: { type: "string" }, description: "근거로 사용한 파일명" },
      },
      required: ["answer", "sources"],
      additionalProperties: false,
    },
  };
}

export { QA_SYSTEM_PROMPT };

export type QaDeps = {
  db: PmDb;
  adapter: CliAdapter;
  index: SpecSection[];
  postMessage(channel: string, threadTs: string, text: string): Promise<void>;
  log(line: string): void;
};

/** pending Q&A를 순차 처리한다. 실패는 failed로 마킹하고 스레드에 알린다 (조용한 실패 금지, 스펙 §5). */
export async function drainQaQueue(deps: QaDeps): Promise<number> {
  let handled = 0;
  for (let item = deps.db.nextPendingQa(); item !== null; item = deps.db.nextPendingQa()) {
    const question = item.text.replace(/<@[A-Z0-9]+>/g, "").trim();
    const { prompt, outputSchema } = buildQaPrompt(question, search(deps.index, question));
    try {
      const raw = await deps.adapter.run({ prompt, outputSchema }, { onLog: deps.log });
      const parsed = JSON.parse(raw) as { answer: string; sources: string[] };
      const sourceNote = parsed.sources.length > 0 ? `\n\n_근거: ${parsed.sources.join(", ")}_` : "";
      await deps.postMessage(item.channel, item.ts, `${parsed.answer}${sourceNote}`);
      deps.db.markQaDone(item.id);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      deps.db.markQaFailed(item.id, msg);
      await deps.postMessage(item.channel, item.ts, `⚠️ 답변 생성에 실패했어요 (${msg}). 다시 멘션해 주세요.`);
    }
    handled += 1;
  }
  return handled;
}
```

- [ ] **Step 5: 통과 확인**

Run: `pnpm test && pnpm typecheck`
Expected: PASS (누적 26 tests)

- [ ] **Step 6: 커밋**

```bash
git add pm-bot/src/specindex.ts pm-bot/src/qa.ts pm-bot/test/specindex.test.ts pm-bot/test/qa.test.ts
git commit -m "feat(pm-bot): 명세 인덱스·Q&A 큐 처리 (#202)"
```

---

### Task 6: 부팅(index.ts) + Socket Mode 와이어링 + 수동 e2e

**Files:**
- Create: `pm-bot/src/index.ts`, `pm-bot/README.md`
- Modify: 없음

**Interfaces:**
- Consumes: 모든 선행 태스크 — `readConfigFile`, `openDb`, `handleMessage`, `backfill`, `buildIndex`, `drainQaQueue`, `createClaudeAdapter(… { systemPrompt: QA_SYSTEM_PROMPT })`
- Produces: 실행 진입점 (`pnpm start`). 자동 테스트 없음 — 유닛은 선행 태스크가 커버, 이 태스크는 수동 e2e로 검증

- [ ] **Step 1: index.ts 작성**

```ts
import bolt from "@slack/bolt";
import { createClaudeAdapter } from "./adapters/claude.js";
import { backfill, handleMessage, type HistoryClient, type SlackMessage } from "./collector.js";
import { readConfigFile } from "./config.js";
import { openDb } from "./db.js";
import { drainQaQueue, QA_SYSTEM_PROMPT } from "./qa.js";
import { buildIndex } from "./specindex.js";

const cfg = readConfigFile(process.env.PM_BOT_CONFIG ?? "./pm-bot.config.json");
const db = openDb(cfg.dbPath);
const index = buildIndex(cfg.specDir);
const adapter = createClaudeAdapter({ bin: cfg.claudeBin, systemPrompt: QA_SYSTEM_PROMPT });

const app = new bolt.App({
  token: process.env.SLACK_BOT_TOKEN,
  appToken: process.env.SLACK_APP_TOKEN,
  socketMode: true,
});

function historyClient(): HistoryClient {
  return {
    async history({ channel, oldest, cursor }) {
      const res = await app.client.conversations.history({ channel, oldest, cursor, limit: 200 });
      return {
        messages: (res.messages ?? []).map((m) => ({ ...m, channel }) as SlackMessage),
        nextCursor: res.response_metadata?.next_cursor || undefined,
      };
    },
    async replies({ channel, ts, cursor }) {
      const res = await app.client.conversations.replies({ channel, ts, cursor, limit: 200 });
      return {
        messages: (res.messages ?? []).map((m) => ({ ...m, channel }) as SlackMessage),
        nextCursor: res.response_metadata?.next_cursor || undefined,
      };
    },
  };
}

async function drain(): Promise<void> {
  await drainQaQueue({
    db,
    adapter,
    index,
    postMessage: async (channel, threadTs, text) => {
      await app.client.chat.postMessage({ channel, thread_ts: threadTs, text });
    },
    log: (line) => console.log(`[qa] ${line}`),
  });
}

app.event("message", async ({ event }) => {
  const ev = event as unknown as SlackMessage;
  if (cfg.channels.includes(ev.channel)) handleMessage(db, ev);
});

app.event("app_mention", async ({ event }) => {
  const ev = event as unknown as SlackMessage & { user: string };
  if (!cfg.channels.includes(ev.channel)) return;
  handleMessage(db, ev); // 멘션도 대화 기록의 일부
  if (db.enqueueQa({ channel: ev.channel, ts: ev.ts, user: ev.user, text: ev.text ?? "" })) void drain();
});

const shutdown = async () => {
  await app.stop();
  db.close();
  process.exit(0);
};
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

await app.start();
console.log(`[pm-bot] Socket Mode 연결됨 — 채널 ${cfg.channels.join(", ")} 감시 중`);
const saved = await backfill(db, historyClient(), cfg.channels);
console.log(`[pm-bot] 백필 완료 — 신규 ${saved}건`);
// 백필로 들어온 멘션 처리: 저장된 메시지 중 봇 멘션을 큐잉하는 것은 Phase 1에선 수동 재멘션으로 갈음.
// (오프라인 중 멘션의 자동 소급 큐잉은 봇 user ID 조회가 필요 — auth.test 후 처리하는 개선을 Phase 2 플랜에 포함)
await drain();
```

- [ ] **Step 2: typecheck·전체 테스트**

Run: `pnpm typecheck && pnpm test`
Expected: PASS — index.ts는 컴파일만 검증 (Slack 연결은 다음 스텝의 수동 e2e)

- [ ] **Step 3: README.md 작성** — 운영 절차 문서화

```markdown
# thumbsup-pm-bot

Slack 지정 채널을 수집하고 명세 근거 Q&A에 답하는 PM 봇 (Phase 1 — 읽기 전용).
설계: `../docs/superpowers/specs/2026-07-19-pm-bot-design.md`

## 준비
1. Slack 앱 (Socket Mode ON) — Bot Token Scopes: `channels:history` `channels:read` `chat:write` `reactions:read` `users:read`, Event Subscriptions: `message.channels` `app_mention`
2. `.env` — `.env.example` 참고 (`SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`)
3. `pm-bot.config.json` — `pm-bot.config.example.json` 참고 (채널 ID·명세 경로)
4. `claude` CLI 로그인 상태 (개인 구독)

## 실행
​```bash
pnpm install
pnpm start          # 포그라운드
pm2 start "pnpm start" --name pm-bot   # 상주
​```

## 동작 확인 (수동 e2e)
1. 지정 채널에 일반 메시지 → `sqlite3 pm-bot.sqlite 'select * from messages'`에 반영
2. `@PM봇 F-45 스펙 뭐야?` 멘션 → 스레드에 근거 포함 답변
3. 봇 종료 → 채널에 메시지 2개 → 재기동 → 백필 로그에 신규 2건, DB 반영 확인
```

- [ ] **Step 4: 수동 e2e 실행 및 결과 기록**

README의 "동작 확인" 3개 시나리오를 테스트 워크스페이스에서 실행하고, 각 결과(성공/실패·로그 요약)를 PR 본문에 기록한다. 실패 시 원인 수정 후 재실행 — 3개 모두 통과 전에는 Task 6을 완료로 표시하지 않는다.

- [ ] **Step 5: 커밋 + PR**

```bash
git add pm-bot/src/index.ts pm-bot/README.md
git commit -m "feat(pm-bot): Socket Mode 부팅·백필·Q&A 와이어링 (#202)"
```

`pr` 스킬 로드 후 PR 생성 — 본문에 `Closes` 없이 `Refs #202` (이슈는 Phase 4까지 열어 둠), 수동 e2e 결과 첨부.

---

## Self-Review 결과

- **스펙 커버리지**: §3.1 수집기(Task 3)·Q&A(Task 5)·백필(Task 3, 6) ✓ / §5 조용한 실패 금지(Task 5 실패 알림) ✓ / §6 골든 테스트는 분석기(Phase 2) 대상이라 이 플랜 범위 아님 ✓. **오프라인 중 멘션의 자동 소급 큐잉은 Phase 1에서 의도적으로 제외** (index.ts 주석 + Phase 2 플랜으로 이월 — 스펙 §3.1 `qa_pending` 요구의 부분 구현임을 명시).
- **플레이스홀더**: Task 4 Step 4의 "bridge 원본과 동일하게 복사"는 원본 파일 경로(`bridge/src/adapters/claude.ts`)가 레포 안에 실재하므로 참조 가능 — 허용. 그 외 TBD 없음.
- **타입 일관성**: `PmDb`·`SlackMessage`·`HistoryClient`·`SpecSection`·`CliAdapter` 시그니처가 태스크 간 일치함을 확인.
