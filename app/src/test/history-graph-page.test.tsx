import { describe, expect, it } from "vitest";
import type { HistoryGraphResponse } from "@/lib/api";

describe("history graph page contract", () => {
  it("uses ordered description lines from the history graph API contract", () => {
    const graph: HistoryGraphResponse = {
      nodes: [
        {
          id: "process",
          label: "프로세스",
          description: [
            "운영체제가 자원을 독립적으로 관리하는 실행 단위입니다.",
            "각 프로세스는 별도의 주소 공간을 가집니다.",
          ],
          learnedAt: "2026-07-10",
          category: "운영체제",
          relatedSteps: [{ stepOrder: 1, topic: "프로세스와 스레드" }],
        },
      ],
      edges: [{ source: "process", target: "thread" }],
    };

    expect(graph.nodes[0]?.description).toEqual([
      "운영체제가 자원을 독립적으로 관리하는 실행 단위입니다.",
      "각 프로세스는 별도의 주소 공간을 가집니다.",
    ]);
  });
});
