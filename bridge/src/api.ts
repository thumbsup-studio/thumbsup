import type { BridgeCli, BridgeConfig } from "./config.js";

export type BridgeJob = { jobId: number; kind: "GENERATE" | "REVIEW"; prompt: string; outputSchema: unknown };
export type ResultOutcome = { jobId: number; status: "SUCCEEDED" | "FAILED"; error?: string };

type Envelope<T> = { code: string; message: string; data: T };

export class ApiError extends Error {
  constructor(
    readonly code: string,
    readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

/**
 * 응답 본문을 먼저 텍스트로 받아 파싱한다. 배포 중 Nginx가 주는 502/503 HTML처럼
 * JSON이 아닌 응답이 오면 원본 SyntaxError 대신 ApiError(INVALID_RESPONSE)로 감싸 던진다.
 */
async function parseEnvelope<T>(res: Response): Promise<Envelope<T>> {
  const text = await res.text();
  try {
    return JSON.parse(text) as Envelope<T>;
  } catch {
    throw new ApiError("INVALID_RESPONSE", res.status, text.slice(0, 200) || "(빈 응답)");
  }
}

/**
 * bridge용 서버 API 클라이언트. 엔벨로프 {code,message,data} 언랩, 401+TOKEN_EXPIRED는
 * refresh 후 1회 재시도(회전 토큰쌍을 persist 콜백으로 저장)한다.
 * 리프레시 요청/응답 형태는 app/src/lib/api/client.ts의 doRefresh()를 미러링한다.
 */
export class BridgeApi {
  private config: BridgeConfig;
  private readonly persist: (c: BridgeConfig) => void;

  constructor(config: BridgeConfig, persist: (c: BridgeConfig) => void) {
    this.config = config;
    this.persist = persist;
  }

  nextJob(): Promise<BridgeJob | null> {
    return this.request<BridgeJob | null>("/authoring/bridge/jobs/next");
  }

  async postLogs(jobId: number, lines: string[]): Promise<void> {
    await this.request<null>(`/authoring/bridge/jobs/${jobId}/logs`, { method: "POST", body: { lines } });
  }

  postResult(jobId: number, cli: BridgeCli, resultJson: string): Promise<ResultOutcome> {
    return this.request<ResultOutcome>(`/authoring/bridge/jobs/${jobId}/result`, {
      method: "POST",
      body: { cli, resultJson },
    });
  }

  async postFail(jobId: number, error: string): Promise<void> {
    await this.request<null>(`/authoring/bridge/jobs/${jobId}/fail`, { method: "POST", body: { error } });
  }

  private async request<T>(path: string, init: { method?: string; body?: unknown; retried?: boolean } = {}): Promise<T> {
    const res = await fetch(`${this.config.serverUrl}/api/v1${path}`, {
      method: init.method ?? "GET",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${this.config.accessToken}` },
      body: init.body === undefined ? undefined : JSON.stringify(init.body),
    });
    const envelope = await parseEnvelope<T>(res);
    if (res.ok) return envelope.data;
    if (res.status === 401 && envelope.code === "TOKEN_EXPIRED" && !init.retried) {
      await this.refresh();
      return this.request<T>(path, { ...init, retried: true });
    }
    throw new ApiError(envelope.code, res.status, envelope.message);
  }

  /** app client.ts의 doRefresh 요청 형태를 미러링: Authorization 없이 refreshToken만 전송, 회전 토큰쌍을 persist. */
  private async refresh(): Promise<void> {
    const res = await fetch(`${this.config.serverUrl}/api/v1/auth/refresh`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ refreshToken: this.config.refreshToken }),
    });
    const envelope = await parseEnvelope<{ accessToken: string; refreshToken: string }>(res);
    if (!res.ok) {
      throw new ApiError(envelope.code, res.status, envelope.message);
    }
    this.config = { ...this.config, accessToken: envelope.data.accessToken, refreshToken: envelope.data.refreshToken };
    this.persist(this.config);
  }
}
