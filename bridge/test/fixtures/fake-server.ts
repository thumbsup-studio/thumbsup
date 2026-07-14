import { createServer, type IncomingHttpHeaders, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import type { AddressInfo } from "node:net";

export type FakeResponse = { status: number; body: unknown };
export type FakeHandler = (req: {
  method: string;
  path: string;
  headers: IncomingHttpHeaders;
  body: unknown;
}) => FakeResponse | Promise<FakeResponse>;

export type ReceivedRequest = { method: string; path: string; headers: IncomingHttpHeaders; body: unknown };

/**
 * `node:http` 기반 가짜 서버. 엔드포인트별로 응답을 큐로 프로그래밍하고, 수신한 요청을 기록한다.
 * bridge의 실제 서버를 대체해 api.ts(T2)·runner.ts(T6) 테스트에서 재사용한다.
 */
export class FakeServer {
  readonly received: ReceivedRequest[] = [];
  url = "";

  private readonly queues = new Map<string, FakeHandler[]>();
  private readonly server: Server = createServer((req, res) => {
    void this.handle(req, res);
  });

  async listen(): Promise<void> {
    await new Promise<void>((resolve) => this.server.listen(0, "127.0.0.1", resolve));
    const { port } = this.server.address() as AddressInfo;
    this.url = `http://127.0.0.1:${port}`;
  }

  async close(): Promise<void> {
    await new Promise<void>((resolve, reject) => {
      this.server.close((err) => (err ? reject(err) : resolve()));
    });
  }

  /** `method path`에 대한 응답을 큐에 등록한다. 같은 키에 여러 번 호출하면 요청마다 순서대로 소비된다. */
  on(method: string, path: string, handler: FakeHandler): void {
    const key = `${method} ${path}`;
    const queue = this.queues.get(key) ?? [];
    queue.push(handler);
    this.queues.set(key, queue);
  }

  private async handle(req: IncomingMessage, res: ServerResponse): Promise<void> {
    const chunks: Buffer[] = [];
    for await (const chunk of req) chunks.push(chunk as Buffer);
    const raw = Buffer.concat(chunks).toString("utf-8");
    const body: unknown = raw ? JSON.parse(raw) : undefined;
    const method = req.method ?? "GET";
    const path = req.url ?? "/";
    this.received.push({ method, path, headers: req.headers, body });

    const key = `${method} ${path}`;
    const handler = this.queues.get(key)?.shift();
    if (!handler) {
      res.writeHead(404, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ code: "NOT_FOUND", message: `핸들러 없음: ${key}`, data: null }));
      return;
    }
    const { status, body: resBody } = await handler({ method, path, headers: req.headers, body });
    res.writeHead(status, { "Content-Type": "application/json" });
    res.end(JSON.stringify(resBody));
  }
}
