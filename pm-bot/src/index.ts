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
  if (db.enqueueQa({ channel: ev.channel, ts: ev.ts, threadTs: ev.thread_ts ?? null, user: ev.user, text: ev.text ?? "" }))
    void drain();
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
