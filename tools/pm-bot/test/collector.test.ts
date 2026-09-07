import { describe, expect, it } from "vitest";
import { openDb } from "../src/db.js";
import { backfill, handleMessage, snapshotCursors, type HistoryClient, type SlackMessage } from "../src/collector.js";

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
    expect(await backfill(db, client, ["C1"], snapshotCursors(db, ["C1"]))).toBe(2);
    expect(db.lastSeenTs("C1")).toBe("2.0");
  });

  it("reply_count 있는 메시지는 스레드 답글까지 저장한다", async () => {
    const db = openDb(":memory:");
    const client = fakeClient(
      { C1: [[{ channel: "C1", ts: "1.0", user: "U1", text: "부모", reply_count: 1 }]] },
      { "1.0": [{ channel: "C1", ts: "1.5", thread_ts: "1.0", user: "U2", text: "답글" }] },
    );
    await backfill(db, client, ["C1"], snapshotCursors(db, ["C1"]));
    expect(db.threadMessages("C1", "1.0").map((m) => m.text)).toEqual(["부모", "답글"]);
  });

  it("스냅샷된 시작점을 oldest로 넘겨 증분 수집한다", async () => {
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
    await backfill(db, client, ["C1"], snapshotCursors(db, ["C1"]));
    expect(seenOldest).toBe("5.0");
  });

  // 회귀: 소켓 연결 후 도착한 라이브 메시지가 백필 시작점을 밀어올려 오프라인 구간을
  // 통째로 건너뛰던 버그. 스냅샷을 app.start() 이전에 고정해 방어한다.
  it("백필 전 라이브 메시지가 저장돼도 스냅샷 시점을 oldest로 유지한다", async () => {
    const db = openDb(":memory:");
    db.upsertMessage({ channel: "C1", ts: "5.0", threadTs: null, user: "U1", text: "종료 직전" });

    // app.start() 이전 — 여기서 시작점이 고정된다
    const cursors = snapshotCursors(db, ["C1"]);

    // 소켓 연결 직후 라이브 메시지 도착 (lastSeenTs를 9.0으로 밀어올림)
    handleMessage(db, { channel: "C1", ts: "9.0", user: "U2", text: "재기동 직후 라이브" });
    expect(db.lastSeenTs("C1")).toBe("9.0");

    let seenOldest: string | undefined;
    const client: HistoryClient = {
      async history({ oldest }) {
        seenOldest = oldest;
        // 오프라인 구간에 쌓여 있던 누락분
        return { messages: [{ channel: "C1", ts: "7.0", user: "U1", text: "오프라인 중 메시지" }] };
      },
      async replies() {
        return { messages: [] };
      },
    };

    await backfill(db, client, ["C1"], cursors);

    expect(seenOldest).toBe("5.0"); // 9.0이면 오프라인 구간을 건너뛴 것
    expect(db.threadMessages("C1", "7.0").map((m) => m.text)).toEqual(["오프라인 중 메시지"]);
  });
});
