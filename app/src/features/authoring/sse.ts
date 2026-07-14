/**
 * 잡 실행 로그 SSE 리더. EventSource를 쓰지 않는 이유: Authorization 헤더를 붙일 수 없음
 * (이 서버는 SSE 스트림도 Bearer 토큰 인증을 요구한다).
 * 프레임워크 무관 함수로 둬서 파서 로직을 단독 테스트할 수 있게 한다.
 */

import { apiUrl } from "@/lib/api/client";
import { tokenStore } from "@/lib/api/token-store";

export type SseHandlers = {
  onLog: (entry: { seq: number; line: string }) => void;
  onStatus: (status: { status: string; draftId: number | null; error: string | null }) => void;
  onError: (error: unknown) => void;
};

/** `event:`/`data:` 필드만 뽑아낸다. `id:` 등 나머지 필드는 무시. */
function parseFrame(frame: string): { name: string; data: string } {
  let name = "message";
  const dataLines: string[] = [];
  for (const rawLine of frame.split("\n")) {
    const line = rawLine.replace(/\r$/, "");
    if (line.startsWith("event:")) name = line.slice(6).trim();
    else if (line.startsWith("data:")) dataLines.push(line.slice(5).trim());
  }
  return { name, data: dataLines.join("\n") };
}

export async function streamJobLogs(
  jobId: number,
  handlers: SseHandlers,
  signal: AbortSignal,
): Promise<void> {
  try {
    const access = tokenStore.getAccess();
    const res = await fetch(apiUrl(`/authoring/jobs/${jobId}/stream`), {
      headers: { Accept: "text/event-stream", Authorization: `Bearer ${access ?? ""}` },
      signal,
    });
    if (!res.ok || !res.body) {
      handlers.onError(new Error(`stream ${res.status}`));
      return;
    }
    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      for (;;) {
        const sep = buffer.indexOf("\n\n");
        if (sep < 0) break;
        const frame = buffer.slice(0, sep);
        buffer = buffer.slice(sep + 2);
        const event = parseFrame(frame);
        if (event.name === "log") handlers.onLog(JSON.parse(event.data));
        else if (event.name === "status") {
          handlers.onStatus(JSON.parse(event.data));
          return;
        }
      }
    }
  } catch (error) {
    if (!signal.aborted) handlers.onError(error);
  }
}
