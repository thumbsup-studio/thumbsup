// Slack 없이 Q&A 두뇌(명세 검색 → 프롬프트 → claude -p)만 돌려보는 임시 하네스.
// 사용: pnpm tsx qa-dryrun.ts <명세디렉터리> "<질문>"
import { createClaudeAdapter } from "./src/adapters/claude.js";
import { buildQaPrompt, QA_SYSTEM_PROMPT } from "./src/qa.js";
import { buildIndex, search } from "./src/specindex.js";

const [specDir, question] = process.argv.slice(2);
if (!specDir || !question) {
  console.error('사용: pnpm tsx qa-dryrun.ts <명세디렉터리> "<질문>"');
  process.exit(1);
}

const index = buildIndex(specDir);
const hits = search(index, question);

console.log(`\n=== 인덱스: ${index.length}개 섹션 / 검색 히트: ${hits.length}개 ===`);
for (const h of hits) {
  console.log(`  · ${h.file} — ${h.heading}  (ids: ${h.ids.join(", ") || "없음"})`);
}
if (hits.length === 0) {
  console.log("  ⚠️  히트 0건 — 봇은 '모른다'고 답할 겁니다.");
}

const { prompt, outputSchema } = buildQaPrompt(question, hits);
console.log(`\n=== claude -p 호출 (프롬프트 ${prompt.length}자) ===`);

const adapter = createClaudeAdapter({ systemPrompt: QA_SYSTEM_PROMPT });
const raw = await adapter.run({ prompt, outputSchema }, { onLog: (l) => process.stderr.write(`  ${l}\n`) });
const parsed = JSON.parse(raw) as { answer: string; sources: string[] };

console.log(`\n=== 봇이 스레드에 올릴 답변 ===\n${parsed.answer}`);
console.log(`\n_근거: ${parsed.sources.join(", ")}_\n`);
