import { describe, expect, it } from "vitest";
import { sanitizedEnv, stripFences } from "../src/adapters/spawn.js";
import { createClaudeAdapter } from "../src/adapters/claude.js";

describe("sanitizedEnv", () => {
  it("API 키를 제거한 복사본을 반환한다", () => {
    const env = sanitizedEnv({ PATH: "/bin", ANTHROPIC_API_KEY: "sk-x", OPENAI_API_KEY: "sk-y" });
    expect(env.PATH).toBe("/bin");
    expect(env.ANTHROPIC_API_KEY).toBeUndefined();
    expect(env.OPENAI_API_KEY).toBeUndefined();
  });
});

describe("stripFences", () => {
  it("json 코드펜스를 벗긴다", () => {
    expect(stripFences('```json\n{"a":1}\n```')).toBe('{"a":1}');
    expect(stripFences('{"a":1}')).toBe('{"a":1}');
  });
});

describe("createClaudeAdapter", () => {
  it("존재하지 않는 바이너리는 stderr 꼬리를 담아 던진다", async () => {
    const adapter = createClaudeAdapter({ bin: "/nonexistent/claude-bin" });
    await expect(
      adapter.run({ prompt: "hi", outputSchema: { type: "object" } }, { onLog: () => {} }),
    ).rejects.toThrow(/claude 실행 실패/);
  });
});
