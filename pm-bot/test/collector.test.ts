import { describe, expect, it } from "vitest";
import { openDb } from "../src/db.js";
import { backfill, handleMessage, type HistoryClient, type SlackMessage } from "../src/collector.js";

describe("handleMessage", () => {
  it("일반 메시지를 저장한다", () => {
    const db = openDb(":memory:");
    handleMessage(db, { channel: "C1", ts: "1.0", user: "U1", text: "안녕" });
    expect(db.threadMessages("C1", "1.0")).toHaveLength(1);
  });

  it("subtype 이벤트·user 없는 이벤트는 무시한다", () => {
    const db = openDb(":memory:");
    handleMessage(db, { channel: "C1", ts: "1.0", user: "U1", text: "x", subtype: "message_changed" });
    handleMessage(db, { channel: "C1", ts: "2.0", text: "봇" });
    expect(db.lastSeenTs("C1")).toBeNull();
  });
});

function fakeClient(pages: Record<string, SlackMessage[][]>, replies: Record<string, SlackMessage[]> = {}): HistoryClient {
  return {
    async history({ channel, cursor }) {
      const idx = cursor ? Number(cursor) : 0;
      const chunk = pages[channel]?.[idx] ?? [];
      const next = pages[channel] && idx + 1 < pages[channel].length ? String(idx + 1) : undefined;
      return { messages: chunk, nextCursor: next };
    },
    async replies({ ts }) {
      return { messages: replies[ts] ?? [] };
    },
  };
}

describe("backfill", () => {
  it("페이지네이션을 따라가며 저장하고 개수를 반환한다", async () => {
    const db = openDb(":memory:");
    const client = fakeClient({
      C1: [
        [{ channel: "C1", ts: "1.0", user: "U1", text: "a" }],
        [{ channel: "C1", ts: "2.0", user: "U1", text: "b" }],
      ],
    });
    expect(await backfill(db, client, ["C1"])).toBe(2);
    expect(db.lastSeenTs("C1")).toBe("2.0");
  });

  it("reply_count 있는 메시지는 스레드 답글까지 저장한다", async () => {
    const db = openDb(":memory:");
    const client = fakeClient(
      { C1: [[{ channel: "C1", ts: "1.0", user: "U1", text: "부모", reply_count: 1 }]] },
      { "1.0": [{ channel: "C1", ts: "1.5", thread_ts: "1.0", user: "U2", text: "답글" }] },
    );
    await backfill(db, client, ["C1"]);
    expect(db.threadMessages("C1", "1.0").map((m) => m.text)).toEqual(["부모", "답글"]);
  });

  it("lastSeenTs를 oldest로 넘겨 증분 수집한다", async () => {
    const db = openDb(":memory:");
    db.upsertMessage({ channel: "C1", ts: "5.0", threadTs: null, user: "U1", text: "기존" });
    let seenOldest: string | undefined;
    const client: HistoryClient = {
      async history({ oldest }) {
        seenOldest = oldest;
        return { messages: [] };
      },
      async replies() {
        return { messages: [] };
      },
    };
    await backfill(db, client, ["C1"]);
    expect(seenOldest).toBe("5.0");
  });
});
