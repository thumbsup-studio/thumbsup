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
