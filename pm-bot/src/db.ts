import Database from "better-sqlite3";

export type MessageRow = { channel: string; ts: string; threadTs: string | null; user: string; text: string };
export type QaRow = { id: number; channel: string; ts: string; user: string; text: string };
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
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  channel TEXT NOT NULL,
  ts      TEXT NOT NULL,
  user    TEXT NOT NULL,
  text    TEXT NOT NULL,
  status  TEXT NOT NULL DEFAULT 'pending',
  error   TEXT,
  UNIQUE (channel, ts)
);
`;

export function openDb(path: string) {
  const db = new Database(path);
  db.pragma("journal_mode = WAL");
  db.exec(SCHEMA);

  const upsertStmt = db.prepare(
    `INSERT INTO messages (channel, ts, thread_ts, user, text) VALUES (@channel, @ts, @threadTs, @user, @text)
     ON CONFLICT (channel, ts) DO UPDATE SET thread_ts = @threadTs, user = @user, text = @text`,
  );
  const threadStmt = db.prepare(
    `SELECT channel, ts, thread_ts AS threadTs, user, text FROM messages
     WHERE channel = ? AND (ts = ? OR thread_ts = ?) ORDER BY CAST(ts AS REAL)`,
  );
  const enqueueStmt = db.prepare(
    `INSERT OR IGNORE INTO qa_pending (channel, ts, user, text) VALUES (@channel, @ts, @user, @text)`,
  );
  const nextQaStmt = db.prepare(
    `SELECT id, channel, ts, user, text FROM qa_pending WHERE status = 'pending' ORDER BY id LIMIT 1`,
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
    enqueueQa(q: { channel: string; ts: string; user: string; text: string }): boolean {
      return enqueueStmt.run(q).changes > 0;
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
