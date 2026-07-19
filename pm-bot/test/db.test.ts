import { describe, expect, it } from "vitest";
import { openDb } from "../src/db.js";

function memDb() {
  return openDb(":memory:");
}

describe("messages", () => {
  it("upsert는 같은 (channel, ts)를 덮어쓴다", () => {
    const db = memDb();
    db.upsertMessage({ channel: "C1", ts: "1.0", threadTs: null, user: "U1", text: "a" });
    db.upsertMessage({ channel: "C1", ts: "1.0", threadTs: null, user: "U1", text: "수정됨" });
    expect(db.threadMessages("C1", "1.0")[0]?.text).toBe("수정됨");
  });

  it("lastSeenTs는 채널별 최대 ts를 반환한다", () => {
    const db = memDb();
    expect(db.lastSeenTs("C1")).toBeNull();
    db.upsertMessage({ channel: "C1", ts: "1.0", threadTs: null, user: "U1", text: "a" });
    db.upsertMessage({ channel: "C1", ts: "2.0", threadTs: null, user: "U1", text: "b" });
    db.upsertMessage({ channel: "C2", ts: "9.0", threadTs: null, user: "U1", text: "c" });
    expect(db.lastSeenTs("C1")).toBe("2.0");
  });

  it("threadMessages는 부모+답글을 ts순으로 반환한다", () => {
    const db = memDb();
    db.upsertMessage({ channel: "C1", ts: "1.0", threadTs: null, user: "U1", text: "부모" });
    db.upsertMessage({ channel: "C1", ts: "3.0", threadTs: "1.0", user: "U2", text: "답2" });
    db.upsertMessage({ channel: "C1", ts: "2.0", threadTs: "1.0", user: "U2", text: "답1" });
    expect(db.threadMessages("C1", "1.0").map((m) => m.text)).toEqual(["부모", "답1", "답2"]);
  });
});

describe("qa_pending", () => {
  it("enqueue는 중복 (channel, ts)에 false를 반환한다", () => {
    const db = memDb();
    expect(db.enqueueQa({ channel: "C1", ts: "1.0", user: "U1", text: "q" })).toBe(true);
    expect(db.enqueueQa({ channel: "C1", ts: "1.0", user: "U1", text: "q" })).toBe(false);
  });

  it("nextPendingQa → markQaDone 흐름", () => {
    const db = memDb();
    db.enqueueQa({ channel: "C1", ts: "1.0", user: "U1", text: "q1" });
    db.enqueueQa({ channel: "C1", ts: "2.0", user: "U1", text: "q2" });
    const first = db.nextPendingQa();
    expect(first?.text).toBe("q1");
    db.markQaDone(first!.id);
    expect(db.nextPendingQa()?.text).toBe("q2");
  });

  it("markQaFailed 후에는 다시 뽑히지 않는다 (조용한 무한 재시도 금지)", () => {
    const db = memDb();
    db.enqueueQa({ channel: "C1", ts: "1.0", user: "U1", text: "q" });
    const row = db.nextPendingQa()!;
    db.markQaFailed(row.id, "claude 실패");
    expect(db.nextPendingQa()).toBeNull();
  });

  it("threadTs를 저장하고 nextPendingQa로 그대로 조회한다", () => {
    const db = memDb();
    db.enqueueQa({ channel: "C1", ts: "1.0", user: "U1", text: "스레드 질문", threadTs: "0.5" });
    db.enqueueQa({ channel: "C1", ts: "2.0", user: "U1", text: "일반 질문" });
    expect(db.nextPendingQa()?.threadTs).toBe("0.5");
    db.markQaDone(db.nextPendingQa()!.id);
    expect(db.nextPendingQa()?.threadTs).toBeNull();
  });
});
