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
