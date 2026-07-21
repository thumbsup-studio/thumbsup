import { resolve } from "node:path";
import bolt from "@slack/bolt";
import { execa } from "execa";
import { createClaudeAdapter } from "./adapters/claude.js";
import { ANALYSIS_SYSTEM_PROMPT, drainAnalysisQueue } from "./analysis.js";
import { backfill, handleMessage, snapshotCursors, type HistoryClient, type SlackMessage } from "./collector.js";
import { readConfigFile } from "./config.js";
import { openDb } from "./db.js";
import { createGhClient, type GhClient } from "./github.js";
import { drainQaQueue, QA_SYSTEM_PROMPT } from "./qa.js";
import { routeReaction, type ReactionEvent } from "./reactions.js";
import { buildIndex } from "./specindex.js";

const cfg = readConfigFile(process.env.PM_BOT_CONFIG ?? "./pm-bot.config.json");
const db = openDb(cfg.dbPath);
const index = buildIndex(cfg.specDir);
const adapter = createClaudeAdapter({ bin: cfg.claudeBin, systemPrompt: QA_SYSTEM_PROMPT });
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

let draining = false;
let drainRequested = false;
async function drain(): Promise<void> {
  if (draining) {
    drainRequested = true;
    return;
  }
  draining = true;
  try {
    do {
      drainRequested = false;
      await drainQaQueue({
        db,
        adapter,
        index,
        postMessage: async (channel, threadTs, text) => {
          await app.client.chat.postMessage({ channel, thread_ts: threadTs, text });
        },
        log: (line) => console.log(`[qa] ${line}`),
      });
    } while (drainRequested);
  } finally {
    draining = false;
  }
}

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

app.event("message", async ({ event }) => {
  const ev = event as unknown as SlackMessage;
  if (cfg.channels.includes(ev.channel)) handleMessage(db, ev);
});

app.event("app_mention", async ({ event }) => {
  const ev = event as unknown as SlackMessage & { user: string };
  if (!cfg.channels.includes(ev.channel)) return;
  handleMessage(db, ev); // 멘션도 대화 기록의 일부
  if (db.enqueueQa({ channel: ev.channel, ts: ev.ts, threadTs: ev.thread_ts ?? null, user: ev.user, text: ev.text ?? "" }))
    void drain();
});

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

const shutdown = async () => {
  await app.stop();
  db.close();
  process.exit(0);
};
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

const botUserId = ((await app.client.auth.test()).user_id ?? "") as string;

// 소켓 연결 전에 백필 시작점을 고정한다 — 연결 후엔 라이브 메시지가 lastSeenTs를 밀어올려
// 오프라인 구간을 건너뛴다. 겹치는 구간은 messages PK(channel, ts) upsert로 멱등 처리된다.
const cursors = snapshotCursors(db, cfg.channels);
await app.start();
console.log(`[pm-bot] Socket Mode 연결됨 — 채널 ${cfg.channels.join(", ")} 감시 중`);
const saved = await backfill(db, historyClient(), cfg.channels, cursors);
console.log(`[pm-bot] 백필 완료 — 신규 ${saved}건`);
const resetCount = db.resetRunningAnalyses();
if (resetCount > 0) console.log(`[pm-bot] 중단됐던 분석 ${resetCount}건 재큐잉`);
// 백필로 들어온 멘션 처리: 저장된 메시지 중 봇 멘션을 큐잉하는 것은 Phase 1에선 수동 재멘션으로 갈음.
// (오프라인 중 멘션의 자동 소급 큐잉은 봇 user ID 조회가 필요 — auth.test 후 처리하는 개선을 Phase 2 플랜에 포함)
await drain();
await drainAnalysis();
