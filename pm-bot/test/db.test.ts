import Database from "better-sqlite3";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
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

  it("thread_ts 컬럼이 없는 구 스키마 DB를 openDb가 마이그레이션한다", () => {
    const dir = mkdtempSync(join(tmpdir(), "pm-bot-db-"));
    const path = join(dir, "legacy.sqlite");
    const legacy = new Database(path);
    legacy.exec(`
      CREATE TABLE qa_pending (
        id      INTEGER PRIMARY KEY AUTOINCREMENT,
        channel TEXT NOT NULL,
        ts      TEXT NOT NULL,
        user    TEXT NOT NULL,
        text    TEXT NOT NULL,
        status  TEXT NOT NULL DEFAULT 'pending',
        error   TEXT,
        UNIQUE (channel, ts)
      );
    `);
    legacy.close();

    const db = openDb(path);
    db.enqueueQa({ channel: "C1", ts: "1.0", user: "U1", text: "구 스키마 질문", threadTs: "1.0" });
    expect(db.nextPendingQa()?.threadTs).toBe("1.0");
    db.close();
  });
});

describe("analyses", () => {
  it("requestAnalysis는 신규 스레드를 pending으로 큐잉한다", () => {
    const db = openDb(":memory:");
    expect(db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" })).toBe("queued");
    expect(db.nextPendingAnalysis()?.threadTs).toBe("1.0");
  });

  it("pending·running 중복 요청은 in_progress로 무시된다", () => {
    const db = openDb(":memory:");
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    expect(db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U2" })).toBe("in_progress");
    db.markAnalysisRunning("C1", "1.0");
    expect(db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U2" })).toBe("in_progress");
  });

  it("done 재요청은 lastMsgTs·resultJson을 보존한 채 재큐잉된다", () => {
    const db = openDb(":memory:");
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    db.markAnalysisRunning("C1", "1.0");
    db.markAnalysisDone("C1", "1.0", "5.0", '{"issueUrls":[]}');
    expect(db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U2" })).toBe("queued");
    const row = db.nextPendingAnalysis();
    expect(row?.lastMsgTs).toBe("5.0");
    expect(row?.resultJson).toBe('{"issueUrls":[]}');
    expect(row?.requestedBy).toBe("U2");
  });

  it("failed 재요청은 error를 비우고 재큐잉된다", () => {
    const db = openDb(":memory:");
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    db.markAnalysisRunning("C1", "1.0");
    db.markAnalysisFailed("C1", "1.0", "boom");
    expect(db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" })).toBe("queued");
    expect(db.nextPendingAnalysis()?.error).toBeNull();
  });

  it("resetRunningAnalyses는 running만 pending으로 되돌린다", () => {
    const db = openDb(":memory:");
    db.requestAnalysis({ channel: "C1", threadTs: "1.0", requestedBy: "U1" });
    db.markAnalysisRunning("C1", "1.0");
    db.requestAnalysis({ channel: "C1", threadTs: "2.0", requestedBy: "U1" });
    db.markAnalysisRunning("C1", "2.0");
    db.markAnalysisDone("C1", "2.0", "2.0", "{}");
    expect(db.resetRunningAnalyses()).toBe(1);
    expect(db.nextPendingAnalysis()?.threadTs).toBe("1.0");
  });
});

describe("spec_prs", () => {
  it("승인 대기 메시지 ts로 역참조한다", () => {
    const db = openDb(":memory:");
    db.insertSpecPr({ prNumber: 7, prUrl: "https://x/7", channel: "C1", messageTs: "9.0", threadTs: "1.0", status: "awaiting" });
    expect(db.specPrByMessage("C1", "9.0")?.prNumber).toBe(7);
    expect(db.specPrByMessage("C1", "8.0")).toBeNull();
    db.markSpecPr(7, "approved");
    expect(db.specPrByMessage("C1", "9.0")?.status).toBe("approved");
  });
});
