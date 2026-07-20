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

  it("실패 알림 게시가 실패해도 drain 루프는 계속 진행하고 로그를 남긴다", async () => {
    const db = openDb(":memory:");
    db.enqueueQa({ channel: "C1", ts: "1.0", user: "U1", text: "질문1" });
    db.enqueueQa({ channel: "C1", ts: "2.0", user: "U1", text: "질문2" });
    const logs: string[] = [];
    const n = await drainQaQueue({
      db,
      index: SECTIONS,
      adapter: { run: async () => { throw new Error("claude 실행 실패"); } },
      postMessage: async () => { throw new Error("slack 일시 오류"); },
      log: (line) => logs.push(line),
    });
    expect(n).toBe(2);
    expect(db.nextPendingQa()).toBeNull();
    expect(logs.some((l) => l.includes("slack 일시 오류"))).toBe(true);
  });

  it("스레드 안 질문은 스레드 대화를 프롬프트에 포함하고 답변을 threadTs로 게시한다", async () => {
    const db = openDb(":memory:");
    db.upsertMessage({ channel: "C1", ts: "1.0", threadTs: null, user: "U1", text: "이 기능 언제 나와요?" });
    db.upsertMessage({ channel: "C1", ts: "2.0", threadTs: "1.0", user: "U2", text: "다음 릴리즈요" });
    db.enqueueQa({ channel: "C1", ts: "3.0", user: "U1", text: "<@BOT> 그거 언제 배포돼?", threadTs: "1.0" });
    let capturedPrompt = "";
    const posted: { channel: string; threadTs: string; text: string }[] = [];
    const n = await drainQaQueue({
      db,
      index: SECTIONS,
      adapter: {
        run: async (input) => {
          capturedPrompt = input.prompt;
          return JSON.stringify({ answer: "다음 릴리즈에 배포됩니다", sources: [] });
        },
      },
      postMessage: async (channel, threadTs, text) => void posted.push({ channel, threadTs, text }),
      log: () => {},
    });
    expect(n).toBe(1);
    expect(capturedPrompt).toContain("스레드 대화");
    expect(capturedPrompt).toContain("다음 릴리즈요");
    expect(posted[0]?.threadTs).toBe("1.0");
  });

  it("어댑터 응답의 answer가 문자열이 아니면 실패로 처리한다", async () => {
    const db = openDb(":memory:");
    db.enqueueQa({ channel: "C1", ts: "1.0", user: "U1", text: "질문" });
    const posted: string[] = [];
    await drainQaQueue({
      db,
      index: SECTIONS,
      adapter: { run: async () => JSON.stringify({ sources: ["14_priority.md"] }) },
      postMessage: async (_c, _t, text) => void posted.push(text),
      log: () => {},
    });
    expect(db.nextPendingQa()).toBeNull();
    expect(posted[0]).toContain("실패");
  });

  it("threadMessages 조회가 던져도 해당 아이템만 failed 처리하고 루프는 계속된다", async () => {
    const realDb = openDb(":memory:");
    const db = {
      ...realDb,
      threadMessages: () => {
        throw new Error("no such column");
      },
    };
    db.enqueueQa({ channel: "C1", ts: "1.0", user: "U1", text: "<@BOT> 스레드 질문", threadTs: "0.5" });
    const posted: string[] = [];
    const n = await drainQaQueue({
      db,
      index: SECTIONS,
      adapter: { run: async () => JSON.stringify({ answer: "답변", sources: [] }) },
      postMessage: async (_c, _t, text) => void posted.push(text),
      log: () => {},
    });
    expect(n).toBe(1);
    expect(db.nextPendingQa()).toBeNull();
    expect(posted[0]).toContain("실패");
  });

  it("adapter.run이 1차 실패해도 재시도로 성공하면 답변을 게시하고 done 처리한다", async () => {
    const db = openDb(":memory:");
    db.enqueueQa({ channel: "C1", ts: "1.0", user: "U1", text: "<@BOT> F-45 뭐야?" });
    const posted: string[] = [];
    let calls = 0;
    const n = await drainQaQueue({
      db,
      index: SECTIONS,
      adapter: {
        run: async () => {
          calls += 1;
          if (calls === 1) throw new Error("일시적 오류");
          return JSON.stringify({ answer: "북마크 기능입니다", sources: ["14_priority.md"] });
        },
      },
      postMessage: async (_c, _t, text) => void posted.push(text),
      log: () => {},
    });
    expect(n).toBe(1);
    expect(calls).toBe(2);
    expect(posted[0]).toContain("북마크 기능입니다");
    expect(db.nextPendingQa()).toBeNull();
  });
});
