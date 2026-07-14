import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { ApiError, BridgeApi } from "../src/api.js";
import type { BridgeConfig } from "../src/config.js";
import { FakeServer } from "./fixtures/fake-server.js";

describe("BridgeApi", () => {
  let server: FakeServer;
  let config: BridgeConfig;
  let persisted: BridgeConfig[];
  let api: BridgeApi;

  beforeEach(async () => {
    server = new FakeServer();
    await server.listen();
    config = { serverUrl: server.url, cli: "CLAUDE", accessToken: "access-1", refreshToken: "refresh-1" };
    persisted = [];
    api = new BridgeApi(config, (c) => persisted.push(c));
  });

  afterEach(async () => {
    await server.close();
  });

  it("nextJob은 data를 언랩하고, 잡이 없으면 null을 반환한다", async () => {
    server.on("GET", "/api/v1/authoring/bridge/jobs/next", () => ({
      status: 200,
      body: {
        code: "SUCCESS",
        message: "",
        data: { jobId: 1, kind: "GENERATE", prompt: "P", outputSchema: { type: "object" } },
      },
    }));
    server.on("GET", "/api/v1/authoring/bridge/jobs/next", () => ({
      status: 200,
      body: { code: "SUCCESS", message: "", data: null },
    }));

    const job = await api.nextJob();
    expect(job).toEqual({ jobId: 1, kind: "GENERATE", prompt: "P", outputSchema: { type: "object" } });

    const empty = await api.nextJob();
    expect(empty).toBeNull();
  });

  it("TOKEN_EXPIRED(401)이면 refresh 후 새 토큰으로 1회 재시도하고 회전된 토큰쌍을 persist한다", async () => {
    server.on("GET", "/api/v1/authoring/bridge/jobs/next", () => ({
      status: 401,
      body: { code: "TOKEN_EXPIRED", message: "만료", data: null },
    }));
    server.on("POST", "/api/v1/auth/refresh", () => ({
      status: 200,
      body: { code: "SUCCESS", message: "", data: { accessToken: "access-2", refreshToken: "refresh-2" } },
    }));
    server.on("GET", "/api/v1/authoring/bridge/jobs/next", () => ({
      status: 200,
      body: { code: "SUCCESS", message: "", data: { jobId: 2, kind: "REVIEW", prompt: "P2", outputSchema: {} } },
    }));

    const job = await api.nextJob();
    expect(job).toEqual({ jobId: 2, kind: "REVIEW", prompt: "P2", outputSchema: {} });

    expect(persisted).toEqual([{ serverUrl: server.url, cli: "CLAUDE", accessToken: "access-2", refreshToken: "refresh-2" }]);

    const nextCalls = server.received.filter((r) => r.method === "GET" && r.path === "/api/v1/authoring/bridge/jobs/next");
    expect(nextCalls).toHaveLength(2);
    expect(nextCalls[0]?.headers.authorization).toBe("Bearer access-1");
    expect(nextCalls[1]?.headers.authorization).toBe("Bearer access-2");

    const refreshCall = server.received.find((r) => r.path === "/api/v1/auth/refresh");
    expect(refreshCall?.body).toEqual({ refreshToken: "refresh-1" });
  });

  it("refresh도 실패하면 ApiError를 던진다", async () => {
    server.on("GET", "/api/v1/authoring/bridge/jobs/next", () => ({
      status: 401,
      body: { code: "TOKEN_EXPIRED", message: "만료", data: null },
    }));
    server.on("POST", "/api/v1/auth/refresh", () => ({
      status: 401,
      body: { code: "UNAUTHORIZED", message: "세션이 만료됐어요.", data: null },
    }));

    const error = await api.nextJob().catch((e: unknown) => e);
    expect(error).toBeInstanceOf(ApiError);
    expect((error as ApiError).code).toBe("UNAUTHORIZED");
    expect((error as ApiError).status).toBe(401);
  });

  it("postResult는 FAILED 응답도 예외 없이 반환한다", async () => {
    server.on("POST", "/api/v1/authoring/bridge/jobs/5/result", () => ({
      status: 200,
      body: { code: "SUCCESS", message: "", data: { jobId: 5, status: "FAILED", error: "검증 실패" } },
    }));

    const outcome = await api.postResult(5, "CLAUDE", '{"quizzes":[]}');
    expect(outcome).toEqual({ jobId: 5, status: "FAILED", error: "검증 실패" });
  });
});
