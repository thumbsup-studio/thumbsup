import { getEventListeners } from "node:events";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import type { CliAdapter } from "../src/adapters/types.js";
import { BridgeApi } from "../src/api.js";
import type { BridgeConfig } from "../src/config.js";
import { runLoop, runOnce } from "../src/runner.js";
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

  it("result 제출 전에 마지막 로그까지 flush된다(서버는 RUNNING 잡만 로그를 받는다)", async () => {
    server.on("GET", "/api/v1/authoring/bridge/jobs/next", () => ({
      status: 200,
      body: {
        code: "SUCCESS",
        message: "",
        data: { jobId: 4, kind: "GENERATE", prompt: "P", outputSchema: {} },
      },
    }));
    server.on("POST", "/api/v1/authoring/bridge/jobs/4/logs", () => ({
      status: 200,
      body: { code: "SUCCESS", message: "", data: null },
    }));
    server.on("POST", "/api/v1/authoring/bridge/jobs/4/result", () => ({
      status: 200,
      body: { code: "SUCCESS", message: "", data: { jobId: 4, status: "SUCCEEDED" } },
    }));

    const quickAdapter: CliAdapter = {
      cli: "CLAUDE",
      async run(_input, { onLog }) {
        onLog("마지막 로그 라인");
        return JSON.stringify({ ok: true });
      },
    };

    // logFlushMs를 사실상 무한대로 둬서 setInterval이 도중에 절대 안 도는 상태를 만든다.
    // 그러면 "마지막 로그 라인"이 /logs로 나가는 유일한 경로는 result 제출 직전 flush뿐이다.
    const outcome = await runOnce({ api, adapter: quickAdapter, logFlushMs: 100_000 });
    expect(outcome).toBe("done");

    const relevantPaths = server.received
      .filter((r) => r.path.startsWith("/api/v1/authoring/bridge/jobs/4/"))
      .map((r) => r.path);
    const logsIndex = relevantPaths.indexOf("/api/v1/authoring/bridge/jobs/4/logs");
    const resultIndex = relevantPaths.indexOf("/api/v1/authoring/bridge/jobs/4/result");
    expect(logsIndex).toBeGreaterThanOrEqual(0);
    expect(logsIndex).toBeLessThan(resultIndex);

    const logsReq = server.received.find((r) => r.path === "/api/v1/authoring/bridge/jobs/4/logs");
    expect((logsReq?.body as { lines: string[] }).lines).toContain("마지막 로그 라인");
  });

  it("postResult가 throw하면 postFail을 시도하고, postFail도 실패해도 'failed'를 반환한다", async () => {
    server.on("GET", "/api/v1/authoring/bridge/jobs/next", () => ({
      status: 200,
      body: {
        code: "SUCCESS",
        message: "",
        data: { jobId: 6, kind: "GENERATE", prompt: "P", outputSchema: {} },
      },
    }));
    server.on("POST", "/api/v1/authoring/bridge/jobs/6/result", () => ({
      status: 500,
      body: { code: "INTERNAL_ERROR", message: "일시적 오류", data: null },
    }));
    server.on("POST", "/api/v1/authoring/bridge/jobs/6/fail", () => ({
      status: 500,
      body: { code: "INTERNAL_ERROR", message: "이것도 실패", data: null },
    }));

    // postResult(500)도, 그 뒤 시도하는 postFail(500)도 둘 다 서버 오류지만
    // runOnce 밖으로 예외가 새어나가지 않고 "failed"로 정상 반환돼야 한다.
    const outcome = await runOnce({ api, adapter: fakeClaudeAdapter, logFlushMs: 10 });
    expect(outcome).toBe("failed");
  });
});

describe("runLoop", () => {
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

  it("idle 사이클을 여러 번 완주해도 signal의 abort 리스너가 누적되지 않는다", async () => {
    for (let i = 0; i < 30; i++) {
      server.on("GET", "/api/v1/authoring/bridge/jobs/next", () => ({
        status: 200,
        body: { code: "SUCCESS", message: "", data: null },
      }));
    }

    const controller = new AbortController();
    const loopPromise = runLoop({ api, adapter: fakeClaudeAdapter, pollIntervalMs: 5 }, controller.signal);

    // idle 사이클(각각 sleep() 완주)이 여러 번 지나가도록 기다린다.
    await new Promise((resolve) => setTimeout(resolve, 60));

    // 정상 완주하는 sleep()마다 abort 리스너를 안 지우면 여기서 여러 개가 쌓여 있어야 한다.
    // 언제나 최대 1개(현재 진행 중인 sleep의 리스너)만 남아있어야 정상이다.
    const listenerCountBeforeAbort = getEventListeners(controller.signal, "abort").length;

    controller.abort();
    await loopPromise;

    expect(listenerCountBeforeAbort).toBeLessThanOrEqual(1);
  });

  it("nextJob이 throw해도 runLoop가 죽지 않고 다음 사이클을 계속한다", async () => {
    server.on("GET", "/api/v1/authoring/bridge/jobs/next", () => ({
      status: 500,
      body: { code: "INTERNAL_ERROR", message: "일시적 서버 오류", data: null },
    }));
    // 이후 호출들은 정상(idle)으로 회복됐다고 가정.
    for (let i = 0; i < 10; i++) {
      server.on("GET", "/api/v1/authoring/bridge/jobs/next", () => ({
        status: 200,
        body: { code: "SUCCESS", message: "", data: null },
      }));
    }

    const controller = new AbortController();
    setTimeout(() => controller.abort(), 60);
    // runLoop 자체가 reject하면(=예외가 새어나가면) await가 곧바로 throw해 테스트가 실패한다.
    await runLoop({ api, adapter: fakeClaudeAdapter, pollIntervalMs: 10 }, controller.signal);

    const nextCalls = server.received.filter((r) => r.path === "/api/v1/authoring/bridge/jobs/next");
    // 첫 호출이 500으로 실패한 뒤에도 폴링을 계속했다는 증거로 최소 2회 이상 호출됐어야 한다.
    expect(nextCalls.length).toBeGreaterThanOrEqual(2);
  });
});
