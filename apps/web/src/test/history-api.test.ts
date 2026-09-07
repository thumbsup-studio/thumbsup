import { beforeEach, describe, expect, it, vi } from "vitest";
import { getHistoryGraph } from "@/lib/api/history";
import { tokenStore } from "@/lib/api/token-store";

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function envelope(code: string, data: unknown = null, message = "OK") {
  return { code, message, data, meta: null };
}

function callInit(mock: ReturnType<typeof vi.fn>, index: number) {
  return mock.mock.calls[index][1] as {
    headers: Record<string, string>;
  };
}

beforeEach(() => {
  localStorage.clear();
  vi.restoreAllMocks();
});

describe("history api", () => {
  it("fetches the knowledge graph through the shared authenticated API client", async () => {
    tokenStore.set({ accessToken: "acc", refreshToken: "ref" });
    const fetchMock = vi.fn().mockResolvedValue(
      jsonResponse(
        200,
        envelope("SUCCESS", {
          nodes: [
            {
              id: "process",
              label: "프로세스",
              description: ["운영체제가 자원을 독립적으로 관리하는 실행 단위입니다."],
              learnedAt: "2026-07-10",
              category: "운영체제",
              relatedSteps: [{ stepOrder: 1, topic: "프로세스와 스레드" }],
            },
          ],
          edges: [{ source: "process", target: "thread" }],
        }),
      ),
    );
    vi.stubGlobal("fetch", fetchMock);

    const graph = await getHistoryGraph();

    expect(graph.nodes[0]?.description).toEqual([
      "운영체제가 자원을 독립적으로 관리하는 실행 단위입니다.",
    ]);
    expect(String(fetchMock.mock.calls[0][0])).toContain("/api/v1/history/graph");
    expect(callInit(fetchMock, 0).headers.Authorization).toBe("Bearer acc");
  });
});
