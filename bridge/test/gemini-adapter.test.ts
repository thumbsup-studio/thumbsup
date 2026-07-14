import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { createGeminiAdapter } from "../src/adapters/gemini.js";

const FIXTURES_DIR = join(dirname(fileURLToPath(import.meta.url)), "fixtures");
function fixturePath(name: string): string {
  return join(FIXTURES_DIR, name);
}

describe("createGeminiAdapter", () => {
  it(".response의 코드펜스를 벗겨 반환하고, 시작 안내와 stderr를 onLog로 중계한다", async () => {
    const adapter = createGeminiAdapter({ bin: fixturePath("fake-gemini.mjs") });
    const logs: string[] = [];
    const result = await adapter.run({ prompt: "P", outputSchema: {} }, { onLog: (l) => logs.push(l) });
    expect(JSON.parse(result)).toEqual({ quizzes: [] });
    expect(logs.some((l) => l.includes("중간 로그를 제공하지 않습니다"))).toBe(true);
    expect(logs.some((l) => l.includes("gemini stderr 라인"))).toBe(true);
  });

  it("자식 env에서 API 키 변수가 제거된다", async () => {
    process.env.GEMINI_API_KEY = "should-not-leak";
    process.env.GOOGLE_API_KEY = "should-not-leak";
    try {
      const adapter = createGeminiAdapter({ bin: fixturePath("fake-gemini-env.mjs") });
      const result = await adapter.run({ prompt: "P", outputSchema: {} }, { onLog: () => {} });
      expect(JSON.parse(result)).toEqual({ hasGeminiKey: false, hasGoogleKey: false });
    } finally {
      delete process.env.GEMINI_API_KEY;
      delete process.env.GOOGLE_API_KEY;
    }
  });

  it("비정상 종료 시 에러를 던진다", async () => {
    const adapter = createGeminiAdapter({ bin: fixturePath("fake-gemini-exit1.mjs") });
    await expect(adapter.run({ prompt: "P", outputSchema: {} }, { onLog: () => {} })).rejects.toThrow(
      /exit 1.*gemini stderr line 3/s,
    );
  });
});
