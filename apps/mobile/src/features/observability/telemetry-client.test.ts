import { describe, expect, it, vi } from "vitest";
import { TelemetryClient } from "./telemetry-client";
import type { TelemetryPayload, TelemetryQueueStore } from "./types";

function payload(): TelemetryPayload {
  return {
    type: "launch",
    occurredAt: "2026-09-08T00:00:00.000Z",
    updateId: "update-1",
    runtimeVersion: "0.1.0",
    channel: "production",
    appVersion: "0.1.0",
    platform: "android",
    deviceModel: "Pixel 9",
    success: true,
    isEmergencyLaunch: false,
    launchDuration: 125,
  };
}

function queueStore(initial: TelemetryPayload[] = []): TelemetryQueueStore & {
  values: TelemetryPayload[];
} {
  return {
    values: [...initial],
    async read() {
      return [...this.values];
    },
    async write(values) {
      this.values = [...values];
    },
  };
}

describe("TelemetryClient", () => {
  it("launch 이벤트를 종류별 엔드포인트로 보낸다", async () => {
    const transport = vi.fn().mockResolvedValue(undefined);
    const store = queueStore();
    const client = new TelemetryClient("https://updates.example.com", store, transport);

    await client.send(payload());

    expect(transport).toHaveBeenCalledWith(
      "https://updates.example.com/api/telemetry/launch",
      payload(),
    );
    expect(store.values).toEqual([]);
  });

  it("전송 실패 이벤트를 큐에 넣고 연결 복구 시 한 번만 재시도한다", async () => {
    const event = payload();
    const store = queueStore();
    const transport = vi.fn().mockRejectedValue(new Error("offline"));
    const client = new TelemetryClient("https://updates.example.com", store, transport);

    await expect(client.send(event)).resolves.toBeUndefined();
    expect(store.values).toEqual([event]);

    await client.retryQueued();
    expect(transport).toHaveBeenCalledTimes(2);
    expect(store.values).toEqual([]);
  });

  it("재시도에 성공한 큐 이벤트를 제거한다", async () => {
    const event = payload();
    const store = queueStore([event]);
    const transport = vi.fn().mockResolvedValue(undefined);
    const client = new TelemetryClient("https://updates.example.com/", store, transport);

    await client.retryQueued();

    expect(transport).toHaveBeenCalledWith(
      "https://updates.example.com/api/telemetry/launch",
      event,
    );
    expect(store.values).toEqual([]);
  });
});
