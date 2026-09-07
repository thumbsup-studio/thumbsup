import type { TelemetryPayload, TelemetryQueueStore } from "./types";

export type TelemetryTransport = (url: string, payload: TelemetryPayload) => Promise<void>;

const defaultTransport: TelemetryTransport = async (url, payload) => {
  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(`Telemetry request failed: ${response.status}`);
};

export class TelemetryClient {
  private operation = Promise.resolve();

  constructor(
    private readonly baseUrl: string,
    private readonly queue: TelemetryQueueStore,
    private readonly transport: TelemetryTransport = defaultTransport,
  ) {}

  send(payload: TelemetryPayload): Promise<void> {
    return this.serial(async () => {
      try {
        await this.post(payload);
      } catch {
        const queued = await this.safeRead();
        await this.safeWrite([...queued, payload].slice(-50));
      }
    });
  }

  retryQueued(): Promise<void> {
    return this.serial(async () => {
      const queued = await this.safeRead();
      if (queued.length === 0) return;
      // 큐에 들어온 이벤트는 연결 복구 시 딱 한 번만 재시도하고 제거한다.
      await this.safeWrite([]);
      await Promise.allSettled(queued.map((payload) => this.post(payload)));
    });
  }

  private post(payload: TelemetryPayload): Promise<void> {
    return this.transport(
      `${this.baseUrl.replace(/\/$/, "")}/api/telemetry/${payload.type}`,
      payload,
    );
  }

  private async safeRead(): Promise<TelemetryPayload[]> {
    try {
      return await this.queue.read();
    } catch {
      return [];
    }
  }

  private async safeWrite(values: TelemetryPayload[]): Promise<void> {
    try {
      await this.queue.write(values);
    } catch {
      // 관측성 저장소 오류는 앱 동작을 막지 않는다.
    }
  }

  private serial(operation: () => Promise<void>): Promise<void> {
    this.operation = this.operation.then(operation, operation);
    return this.operation;
  }
}
