import { beforeEach, describe, expect, it, vi } from "vitest";
import { streamJobLogs } from "@/features/authoring/sse";
import { tokenStore } from "@/lib/api/token-store";

/** SSE 텍스트를 청크 단위로 순차 enqueue하는 스트림 응답. 청크 경계가 이벤트 중간을 잘라도 안전한지 검증용. */
function sseResponse(chunks: string[], status = 200): Response {
  const encoder = new TextEncoder();
  let index = 0;
  const stream = new ReadableStream<Uint8Array>({
    pull(controller) {
      if (index < chunks.length) {
        controller.enqueue(encoder.encode(chunks[index]));
        index += 1;
      } else {
        controller.close();
      }
    },
  });
  return new Response(stream, { status, headers: { "Content-Type": "text/event-stream" } });
}

function callInit(mock: ReturnType<typeof vi.fn>, index: number) {
  return mock.mock.calls[index][1] as { headers: Record<string, string>; signal?: AbortSignal };
}

beforeEach(() => {
  localStorage.clear();
  vi.restoreAllMocks();
});

describe("streamJobLogs", () => {
  it("log 이벤트를 파싱해 onLog를 호출한다 — 청크 경계가 이벤트 중간을 잘라도 안전하다", async () => {
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValue(
          sseResponse([
            'event: log\nid: 1\ndata: {"seq":1,"line":"시작"}\n\n',
            'event: log\nid: 2\ndata: {"seq":2,"li',
            'ne":"진행"}\n\n',
          ]),
        ),
    );
    const onLog = vi.fn();

    await streamJobLogs(
      7,
      { onLog, onStatus: vi.fn(), onError: vi.fn() },
      new AbortController().signal,
    );

    expect(onLog).toHaveBeenNthCalledWith(1, { seq: 1, line: "시작" });
    expect(onLog).toHaveBeenNthCalledWith(2, { seq: 2, line: "진행" });
  });

  it("status 이벤트를 받으면 onStatus 후 정상 종료한다", async () => {
    vi.stubGlobal(
      "fetch",
      vi
        .fn()
        .mockResolvedValue(
          sseResponse([
            'event: status\ndata: {"status":"SUCCEEDED","draftId":42,"error":null,"outlineId":9}\n\n',
          ]),
        ),
    );
    const onStatus = vi.fn();

    await streamJobLogs(
      7,
      { onLog: vi.fn(), onStatus, onError: vi.fn() },
      new AbortController().signal,
    );

    expect(onStatus).toHaveBeenCalledWith({
      status: "SUCCEEDED",
      draftId: 42,
      error: null,
      outlineId: 9,
    });
  });

  it("Authorization 헤더에 tokenStore의 access 토큰을 붙인다", async () => {
    tokenStore.set({ accessToken: "acc", refreshToken: "ref" });
    const fetchMock = vi.fn().mockResolvedValue(sseResponse([]));
    vi.stubGlobal("fetch", fetchMock);

    await streamJobLogs(
      7,
      { onLog: vi.fn(), onStatus: vi.fn(), onError: vi.fn() },
      new AbortController().signal,
    );

    expect(String(fetchMock.mock.calls[0][0])).toBe(
      "https://thumbsup-api.duckdns.org/api/v1/authoring/jobs/7/stream",
    );
    expect(callInit(fetchMock, 0).headers.Authorization).toBe("Bearer acc");
  });

  it("HTTP 401이면 onError를 호출한다", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(null, { status: 401 })));
    const onError = vi.fn();

    await streamJobLogs(
      7,
      { onLog: vi.fn(), onStatus: vi.fn(), onError },
      new AbortController().signal,
    );

    expect(onError).toHaveBeenCalledTimes(1);
  });

  it("signal이 이미 abort된 상태의 에러는 onError를 호출하지 않는다", async () => {
    const controller = new AbortController();
    vi.stubGlobal(
      "fetch",
      vi.fn().mockImplementation(() => {
        controller.abort();
        return Promise.reject(new DOMException("aborted", "AbortError"));
      }),
    );
    const onError = vi.fn();

    await streamJobLogs(7, { onLog: vi.fn(), onStatus: vi.fn(), onError }, controller.signal);

    expect(onError).not.toHaveBeenCalled();
  });
});
