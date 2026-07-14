import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { createClaudeAdapter } from "../src/adapters/claude.js";

const FIXTURES_DIR = join(dirname(fileURLToPath(import.meta.url)), "fixtures");
function fixturePath(name: string): string {
  return join(FIXTURES_DIR, name);
}

describe("createClaudeAdapter", () => {
  it("structured_output이 있으면 그것을 JSON 문자열로 반환한다", async () => {
    const adapter = createClaudeAdapter({ bin: fixturePath("fake-claude.mjs") });
    const logs: string[] = [];
    const result = await adapter.run({ prompt: "P", outputSchema: { type: "object" } }, { onLog: (l) => logs.push(l) });
    expect(JSON.parse(result)).toEqual({ quizzes: [{ type: "OX" }] });
    expect(logs.some((l) => l.includes("문제 생성 중"))).toBe(true);
  });

  it("structured_output이 없으면 result 문자열의 코드펜스를 벗겨 반환한다", async () => {
    const adapter = createClaudeAdapter({ bin: fixturePath("fake-claude-nofences.mjs") });
    const logs: string[] = [];
    const result = await adapter.run({ prompt: "P", outputSchema: { type: "object" } }, { onLog: (l) => logs.push(l) });
    expect(JSON.parse(result)).toEqual({ quizzes: [{ type: "MULTIPLE_CHOICE" }] });
    expect(logs.some((l) => l.includes("리뷰 중"))).toBe(true);
  });

  it("비정상 종료 시 stderr 꼬리를 담아 throw한다", async () => {
    const adapter = createClaudeAdapter({ bin: fixturePath("fake-claude-exit1.mjs") });
    await expect(adapter.run({ prompt: "P", outputSchema: {} }, { onLog: () => {} })).rejects.toThrow(
      /exit 1.*stderr line 3/s,
    );
  });

  it("자식 env에서 API 키 변수가 제거된다", async () => {
    process.env.ANTHROPIC_API_KEY = "should-not-leak";
    try {
      const adapter = createClaudeAdapter({ bin: fixturePath("fake-claude-env.mjs") });
      const result = await adapter.run({ prompt: "P", outputSchema: {} }, { onLog: () => {} });
      expect(JSON.parse(result)).toEqual({ hasAnthropicKey: false });
    } finally {
      delete process.env.ANTHROPIC_API_KEY;
    }
  });
});
