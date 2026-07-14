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

  it("stderr를 실시간으로 onLog에 중계한다(프로세스 종료를 기다려 한꺼번에 쏟아내지 않는다)", async () => {
    const adapter = createGeminiAdapter({ bin: fixturePath("fake-gemini-slow-stderr.mjs") });
    const start = Date.now();
    let firstLineAt: number | null = null;
    const result = await adapter.run(
      { prompt: "P", outputSchema: {} },
      {
        onLog: (l) => {
          if (l.includes("slow line 1") && firstLineAt === null) firstLineAt = Date.now() - start;
        },
      },
    );
    expect(JSON.parse(result)).toEqual({ ok: true });
    // 픽스처는 첫 줄 직후 150ms를 쉬고서야 둘째 줄+종료. 배치 릴레이라면 첫 줄도 150ms 이후에야
    // onLog에 도착하므로, 훨씬 이르게(100ms 미만) 도착했는지로 실시간 중계를 검증한다.
    expect(firstLineAt).not.toBeNull();
    expect(firstLineAt).toBeLessThan(100);
  });
});
