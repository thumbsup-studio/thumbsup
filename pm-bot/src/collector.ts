import type { PmDb } from "./db.js";

export type SlackMessage = {
  channel: string;
  ts: string;
  thread_ts?: string;
  user?: string;
  text?: string;
  subtype?: string;
  reply_count?: number;
};

export type HistoryPage = { messages: SlackMessage[]; nextCursor?: string };
export type HistoryClient = {
  history(params: { channel: string; oldest?: string; cursor?: string }): Promise<HistoryPage>;
  replies(params: { channel: string; ts: string; cursor?: string }): Promise<HistoryPage>;
};

/** 수정·삭제·시스템 메시지(subtype 존재)와 user 없는 이벤트는 수집하지 않는다. */
export function handleMessage(db: PmDb, ev: SlackMessage): void {
  if (ev.subtype || !ev.user || !ev.text) return;
  db.upsertMessage({ channel: ev.channel, ts: ev.ts, threadTs: ev.thread_ts ?? null, user: ev.user, text: ev.text });
}

async function drainPages(
  fetch: (cursor?: string) => Promise<HistoryPage>,
  onMessage: (m: SlackMessage) => void,
): Promise<void> {
  let cursor: string | undefined;
  do {
    const page = await fetch(cursor);
    for (const m of page.messages) onMessage(m);
    cursor = page.nextCursor;
  } while (cursor);
}

/** 채널별 백필 시작점. 소켓 연결 전에 고정해야 하므로 backfill의 필수 인자로 받는다. */
export type BackfillCursors = ReadonlyMap<string, string | undefined>;

/**
 * 백필 시작점을 고정한다. **반드시 app.start() 이전에 호출한다** — 소켓이 연결되면
 * 라이브 메시지가 먼저 저장되어 lastSeenTs가 최신 ts로 올라가고, 그걸 oldest로 쓰면
 * 봇이 꺼져 있던 구간이 통째로 조회 범위 밖으로 빠진다.
 */
export function snapshotCursors(db: PmDb, channels: string[]): BackfillCursors {
  return new Map(channels.map((channel) => [channel, db.lastSeenTs(channel) ?? undefined]));
}

/** 스냅샷된 시작점 이후를 수집한다. 반환 = 새로 저장된 메시지 수. */
export async function backfill(
  db: PmDb,
  client: HistoryClient,
  channels: string[],
  cursors: BackfillCursors,
): Promise<number> {
  let saved = 0;
  for (const channel of channels) {
    const oldest = cursors.get(channel);
    const threadParents: SlackMessage[] = [];
    await drainPages(
      (cursor) => client.history({ channel, oldest, cursor }),
      (m) => {
        if (m.subtype || !m.user || !m.text) return;
        db.upsertMessage({ channel, ts: m.ts, threadTs: m.thread_ts ?? null, user: m.user, text: m.text });
        saved += 1;
        if ((m.reply_count ?? 0) > 0) threadParents.push(m);
      },
    );
    for (const parent of threadParents) {
      await drainPages(
        (cursor) => client.replies({ channel, ts: parent.ts, cursor }),
        (m) => {
          if (m.subtype || !m.user || !m.text || m.ts === parent.ts) return;
          db.upsertMessage({ channel, ts: m.ts, threadTs: m.thread_ts ?? parent.ts, user: m.user, text: m.text });
          saved += 1;
        },
      );
    }
  }
  return saved;
}
