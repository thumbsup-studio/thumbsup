import Database from "better-sqlite3";

export type MessageRow = { channel: string; ts: string; threadTs: string | null; user: string; text: string };
export type QaRow = { id: number; channel: string; ts: string; user: string; text: string; threadTs: string | null };
export type AnalysisRow = {
  channel: string;
  threadTs: string;
  status: string;
  requestedBy: string;
  lastMsgTs: string | null;
  resultJson: string | null;
  error: string | null;
};
export type SpecPrRow = {
  prNumber: number;
  prUrl: string;
  channel: string;
  messageTs: string;
  threadTs: string;
  status: string;
};
export type PmDb = ReturnType<typeof openDb>;

const SCHEMA = `
CREATE TABLE IF NOT EXISTS messages (
  channel   TEXT NOT NULL,
  ts        TEXT NOT NULL,
  thread_ts TEXT,
  user      TEXT NOT NULL,
  text      TEXT NOT NULL,
  PRIMARY KEY (channel, ts)
);
CREATE INDEX IF NOT EXISTS idx_messages_thread ON messages (channel, thread_ts);
CREATE TABLE IF NOT EXISTS qa_pending (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  channel   TEXT NOT NULL,
  ts        TEXT NOT NULL,
  user      TEXT NOT NULL,
  text      TEXT NOT NULL,
  thread_ts TEXT,
  status    TEXT NOT NULL DEFAULT 'pending',
  error     TEXT,
  UNIQUE (channel, ts)
);
CREATE TABLE IF NOT EXISTS analyses (
  channel      TEXT NOT NULL,
  thread_ts    TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'pending',
  requested_by TEXT NOT NULL,
  last_msg_ts  TEXT,
  result_json  TEXT,
  error        TEXT,
  PRIMARY KEY (channel, thread_ts)
);
CREATE TABLE IF NOT EXISTS spec_prs (
  pr_number  INTEGER PRIMARY KEY,
  pr_url     TEXT NOT NULL,
  channel    TEXT NOT NULL,
  message_ts TEXT NOT NULL,
  thread_ts  TEXT NOT NULL,
  status     TEXT NOT NULL DEFAULT 'awaiting'
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_spec_prs_msg ON spec_prs (channel, message_ts);
`;

export function openDb(path: string) {
  const db = new Database(path);
  db.pragma("journal_mode = WAL");
  db.exec(SCHEMA);
  try {
    db.exec("ALTER TABLE qa_pending ADD COLUMN thread_ts TEXT");
  } catch {
    // 이미 컬럼이 있으면 duplicate column 에러 — 무시 (신규 DB는 CREATE TABLE이 포함)
  }

  const upsertStmt = db.prepare(
    `INSERT INTO messages (channel, ts, thread_ts, user, text) VALUES (@channel, @ts, @threadTs, @user, @text)
     ON CONFLICT (channel, ts) DO UPDATE SET thread_ts = @threadTs, user = @user, text = @text`,
  );
  const threadStmt = db.prepare(
    `SELECT channel, ts, thread_ts AS threadTs, user, text FROM messages
     WHERE channel = ? AND (ts = ? OR thread_ts = ?) ORDER BY CAST(ts AS REAL)`,
  );
  const enqueueStmt = db.prepare(
    `INSERT OR IGNORE INTO qa_pending (channel, ts, user, text, thread_ts) VALUES (@channel, @ts, @user, @text, @threadTs)`,
  );
  const nextQaStmt = db.prepare(
    `SELECT id, channel, ts, user, text, thread_ts AS threadTs FROM qa_pending WHERE status = 'pending' ORDER BY id LIMIT 1`,
  );
  const doneStmt = db.prepare(`UPDATE qa_pending SET status = 'done' WHERE id = ?`);
  const failStmt = db.prepare(`UPDATE qa_pending SET status = 'failed', error = ? WHERE id = ?`);
  const maxTsStmt = db.prepare(`SELECT ts FROM messages WHERE channel = ? ORDER BY CAST(ts AS REAL) DESC LIMIT 1`);

  const getAnalysisStmt = db.prepare(
    `SELECT channel, thread_ts AS threadTs, status, requested_by AS requestedBy,
            last_msg_ts AS lastMsgTs, result_json AS resultJson, error
     FROM analyses WHERE channel = ? AND thread_ts = ?`,
  );
  const insertAnalysisStmt = db.prepare(
    `INSERT INTO analyses (channel, thread_ts, status, requested_by) VALUES (?, ?, 'pending', ?)`,
  );
  const requeueAnalysisStmt = db.prepare(
    `UPDATE analyses SET status = 'pending', requested_by = ?, error = NULL WHERE channel = ? AND thread_ts = ?`,
  );
  const nextAnalysisStmt = db.prepare(
    `SELECT channel, thread_ts AS threadTs, status, requested_by AS requestedBy,
            last_msg_ts AS lastMsgTs, result_json AS resultJson, error
     FROM analyses WHERE status = 'pending' ORDER BY thread_ts LIMIT 1`,
  );
  const analysisStatusStmt = db.prepare(`UPDATE analyses SET status = ? WHERE channel = ? AND thread_ts = ?`);
  const analysisDoneStmt = db.prepare(
    `UPDATE analyses SET status = 'done', last_msg_ts = ?, result_json = ?, error = NULL WHERE channel = ? AND thread_ts = ?`,
  );
  const analysisFailStmt = db.prepare(`UPDATE analyses SET status = 'failed', error = ? WHERE channel = ? AND thread_ts = ?`);
  const resetRunningStmt = db.prepare(`UPDATE analyses SET status = 'pending' WHERE status = 'running'`);
  const insertSpecPrStmt = db.prepare(
    `INSERT INTO spec_prs (pr_number, pr_url, channel, message_ts, thread_ts, status)
     VALUES (@prNumber, @prUrl, @channel, @messageTs, @threadTs, @status)`,
  );
  const specPrByMsgStmt = db.prepare(
    `SELECT pr_number AS prNumber, pr_url AS prUrl, channel, message_ts AS messageTs, thread_ts AS threadTs, status
     FROM spec_prs WHERE channel = ? AND message_ts = ?`,
  );
  const markSpecPrStmt = db.prepare(`UPDATE spec_prs SET status = ? WHERE pr_number = ?`);

  return {
    upsertMessage(m: MessageRow): void {
      upsertStmt.run(m);
    },
    lastSeenTs(channel: string): string | null {
      const row = maxTsStmt.get(channel) as { ts: string } | undefined;
      return row?.ts ?? null;
    },
    threadMessages(channel: string, threadTs: string): MessageRow[] {
      return threadStmt.all(channel, threadTs, threadTs) as MessageRow[];
    },
    enqueueQa(q: { channel: string; ts: string; user: string; text: string; threadTs?: string | null }): boolean {
      return enqueueStmt.run({ ...q, threadTs: q.threadTs ?? null }).changes > 0;
    },
    nextPendingQa(): QaRow | null {
      return (nextQaStmt.get() as QaRow | undefined) ?? null;
    },
    markQaDone(id: number): void {
      doneStmt.run(id);
    },
    markQaFailed(id: number, error: string): void {
      failStmt.run(error, id);
    },
    requestAnalysis(q: { channel: string; threadTs: string; requestedBy: string }): "queued" | "in_progress" {
      const row = getAnalysisStmt.get(q.channel, q.threadTs) as AnalysisRow | undefined;
      if (!row) {
        insertAnalysisStmt.run(q.channel, q.threadTs, q.requestedBy);
        return "queued";
      }
      if (row.status === "pending" || row.status === "running") return "in_progress";
      requeueAnalysisStmt.run(q.requestedBy, q.channel, q.threadTs); // done의 last_msg_ts·result_json 보존 — drain의 재트리거 판단 근거
      return "queued";
    },
    nextPendingAnalysis(): AnalysisRow | null {
      return (nextAnalysisStmt.get() as AnalysisRow | undefined) ?? null;
    },
    markAnalysisRunning(channel: string, threadTs: string): void {
      analysisStatusStmt.run("running", channel, threadTs);
    },
    markAnalysisDone(channel: string, threadTs: string, lastMsgTs: string, resultJson: string): void {
      analysisDoneStmt.run(lastMsgTs, resultJson, channel, threadTs);
    },
    markAnalysisFailed(channel: string, threadTs: string, error: string): void {
      analysisFailStmt.run(error, channel, threadTs);
    },
    resetRunningAnalyses(): number {
      return resetRunningStmt.run().changes;
    },
    insertSpecPr(row: SpecPrRow): void {
      insertSpecPrStmt.run(row);
    },
    specPrByMessage(channel: string, messageTs: string): SpecPrRow | null {
      return (specPrByMsgStmt.get(channel, messageTs) as SpecPrRow | undefined) ?? null;
    },
    markSpecPr(prNumber: number, status: "approved" | "rejected"): void {
      markSpecPrStmt.run(status, prNumber);
    },
    close(): void {
      db.close();
    },
  };
}
