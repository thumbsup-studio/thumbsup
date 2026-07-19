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
