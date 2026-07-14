import { afterEach, beforeEach, describe, expect, it } from "vitest";
import type { CliAdapter } from "../src/adapters/types.js";
import { BridgeApi } from "../src/api.js";
import type { BridgeConfig } from "../src/config.js";
import { runOnce } from "../src/runner.js";
import { FakeServer } from "./fixtures/fake-server.js";

const fakeClaudeAdapter: CliAdapter = {
  cli: "CLAUDE",
  async run(_input, { onLog }) {
    onLog("문제 생성 중...");
    return JSON.stringify({ quizzes: [{ type: "OX" }] });
  },
};

const throwingAdapter: CliAdapter = {
  cli: "CLAUDE",
  async run() {
    throw new Error("어댑터 실행 실패");
  },
};

function logLinesFor(server: FakeServer, jobId: number): string[] {
  return server.received
    .filter((r) => r.method === "POST" && r.path === `/api/v1/authoring/bridge/jobs/${jobId}/logs`)
    .flatMap((r) => (r.body as { lines: string[] }).lines);
}

describe("runOnce", () => {
  let server: FakeServer;
  let config: BridgeConfig;
  let api: BridgeApi;

  beforeEach(async () => {
    server = new FakeServer();
    await server.listen();
    config = { serverUrl: server.url, cli: "CLAUDE", accessToken: "a", refreshToken: "r" };
    api = new BridgeApi(config, () => {});
  });

  afterEach(async () => {
    await server.close();
  });

  it("잡 수령→실행→로그 배치 전송→result 제출의 전체 사이클", async () => {
    server.on("GET", "/api/v1/authoring/bridge/jobs/next", () => ({
      status: 200,
      body: {
        code: "SUCCESS",
        message: "",
        data: { jobId: 1, kind: "GENERATE", prompt: "P", outputSchema: { type: "object" } },
      },
    }));
    server.on("POST", "/api/v1/authoring/bridge/jobs/1/logs", () => ({
      status: 200,
      body: { code: "SUCCESS", message: "", data: null },
    }));
    server.on("POST", "/api/v1/authoring/bridge/jobs/1/result", () => ({
      status: 200,
      body: { code: "SUCCESS", message: "", data: { jobId: 1, status: "SUCCEEDED" } },
    }));

    const outcome = await runOnce({ api, adapter: fakeClaudeAdapter, logFlushMs: 10 });
    expect(outcome).toBe("done");
    expect(logLinesFor(server, 1)).toContain("문제 생성 중...");

    const resultReq = server.received.find((r) => r.path === "/api/v1/authoring/bridge/jobs/1/result");
    const resultBody = resultReq?.body as { cli: string; resultJson: string };
    expect(resultBody.cli).toBe("CLAUDE");
    expect(JSON.parse(resultBody.resultJson)).toHaveProperty("quizzes");
  });

  it("어댑터가 throw하면 fail을 제출한다", async () => {
    server.on("GET", "/api/v1/authoring/bridge/jobs/next", () => ({
      status: 200,
      body: {
        code: "SUCCESS",
        message: "",
        data: { jobId: 2, kind: "GENERATE", prompt: "P", outputSchema: {} },
      },
    }));
    server.on("POST", "/api/v1/authoring/bridge/jobs/2/fail", () => ({
      status: 200,
      body: { code: "SUCCESS", message: "", data: null },
    }));

    const outcome = await runOnce({ api, adapter: throwingAdapter, logFlushMs: 10 });
    expect(outcome).toBe("failed");

    const failReq = server.received.find((r) => r.path === "/api/v1/authoring/bridge/jobs/2/fail");
    expect((failReq?.body as { error: string }).error).toContain("어댑터 실행 실패");
  });

  it("잡이 없으면 idle을 반환한다", async () => {
    server.on("GET", "/api/v1/authoring/bridge/jobs/next", () => ({
      status: 200,
      body: { code: "SUCCESS", message: "", data: null },
    }));

    const outcome = await runOnce({ api, adapter: fakeClaudeAdapter, logFlushMs: 10 });
    expect(outcome).toBe("idle");
  });

  it("로그 flush가 겹치지 않는다 — postLogs가 동시에 두 번 나가지 않는다", async () => {
    server.on("GET", "/api/v1/authoring/bridge/jobs/next", () => ({
      status: 200,
      body: {
        code: "SUCCESS",
        message: "",
        data: { jobId: 3, kind: "GENERATE", prompt: "P", outputSchema: {} },
      },
    }));

    let concurrent = 0;
    let maxConcurrent = 0;
    // /logs 서버 응답을 인위적으로 지연시켜, 짧은 flush 주기(logFlushMs)와 겹칠 여지를 만든다.
    for (let i = 0; i < 20; i++) {
      server.on("POST", "/api/v1/authoring/bridge/jobs/3/logs", async () => {
        concurrent++;
        maxConcurrent = Math.max(maxConcurrent, concurrent);
        await new Promise((resolve) => setTimeout(resolve, 20));
        concurrent--;
        return { status: 200, body: { code: "SUCCESS", message: "", data: null } };
      });
    }
    server.on("POST", "/api/v1/authoring/bridge/jobs/3/result", () => ({
      status: 200,
      body: { code: "SUCCESS", message: "", data: { jobId: 3, status: "SUCCEEDED" } },
    }));

    const slowAdapter: CliAdapter = {
      cli: "CLAUDE",
      async run(_input, { onLog }) {
        for (let i = 0; i < 5; i++) {
          onLog(`line ${i}`);
          await new Promise((resolve) => setTimeout(resolve, 15));
        }
        return JSON.stringify({ ok: true });
      },
    };

    const outcome = await runOnce({ api, adapter: slowAdapter, logFlushMs: 10 });
    expect(outcome).toBe("done");
    expect(maxConcurrent).toBeLessThanOrEqual(1);
  });
});
