import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { createCodexAdapter } from "../src/adapters/codex.js";

const FIXTURES_DIR = join(dirname(fileURLToPath(import.meta.url)), "fixtures");
function fixturePath(name: string): string {
  return join(FIXTURES_DIR, name);
}

describe("createCodexAdapter", () => {
  it("마지막 agent_message 텍스트(펜스 제거)를 반환하고, 중간 이벤트는 onLog로 남는다", async () => {
    const adapter = createCodexAdapter({ bin: fixturePath("fake-codex.mjs") });
    const logs: string[] = [];
    const result = await adapter.run({ prompt: "P", outputSchema: { type: "object" } }, { onLog: (l) => logs.push(l) });
    expect(JSON.parse(result)).toEqual({ quizzes: [{ type: "OX" }] });
    expect(logs.some((l) => l.includes("turn.completed"))).toBe(true);
  });

  it("--output-schema 인자를 넘기지 않는다(OpenAI strict 스키마 규격과 비호환 — 실기기 확인)", async () => {
    const adapter = createCodexAdapter({ bin: fixturePath("fake-codex.mjs") });
    const logs: string[] = [];
    await adapter.run(
      { prompt: "P", outputSchema: { type: "object", required: ["quizzes"] } },
      { onLog: (l) => logs.push(l) },
    );
    expect(logs.some((l) => l.includes("--output-schema"))).toBe(false);
  });

  it("자식 env에서 API 키 변수가 제거된다", async () => {
    process.env.OPENAI_API_KEY = "should-not-leak";
    try {
      const adapter = createCodexAdapter({ bin: fixturePath("fake-codex-env.mjs") });
      const result = await adapter.run({ prompt: "P", outputSchema: {} }, { onLog: () => {} });
      expect(JSON.parse(result)).toEqual({ hasOpenAiKey: false });
    } finally {
      delete process.env.OPENAI_API_KEY;
    }
  });

  it("비정상 종료 시 에러를 던진다", async () => {
    const adapter = createCodexAdapter({ bin: fixturePath("fake-codex-exit1.mjs") });
    await expect(adapter.run({ prompt: "P", outputSchema: {} }, { onLog: () => {} })).rejects.toThrow(
      /exit 1.*codex stderr line 3/s,
    );
  });

  it("error 이벤트를 만나면 메시지를 포함해 onLog로 남긴다", async () => {
    const adapter = createCodexAdapter({ bin: fixturePath("fake-codex-error-event.mjs") });
    const logs: string[] = [];
    const result = await adapter.run({ prompt: "P", outputSchema: {} }, { onLog: (l) => logs.push(l) });
    expect(JSON.parse(result)).toEqual({ ok: true });
    expect(logs.some((l) => l.includes("[error] Invalid schema for response_format"))).toBe(true);
  });
});
