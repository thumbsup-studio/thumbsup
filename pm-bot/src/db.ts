import Database from "better-sqlite3";

export type MessageRow = { channel: string; ts: string; threadTs: string | null; user: string; text: string };
export type QaRow = { id: number; channel: string; ts: string; user: string; text: string; threadTs: string | null };
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
    close(): void {
      db.close();
    },
  };
}
