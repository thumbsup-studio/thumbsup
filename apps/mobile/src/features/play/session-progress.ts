import AsyncStorage from "@react-native-async-storage/async-storage";

const SESSION_KEY_PREFIX = "thumbsup:play-session";

export type PlaySession = {
  answered: number;
  correct: number;
  combo: number;
  bestCombo: number;
};

export type SessionStorage = Pick<typeof AsyncStorage, "getItem" | "setItem" | "removeItem">;

export const emptySession: PlaySession = { answered: 0, correct: 0, combo: 0, bestCombo: 0 };

export function applyAnswer(session: PlaySession, correct: boolean): PlaySession {
  const combo = correct ? session.combo + 1 : 0;
  return {
    answered: session.answered + 1,
    correct: session.correct + (correct ? 1 : 0),
    combo,
    bestCombo: Math.max(session.bestCombo, combo),
  };
}

function sessionKey(stepOrder: number) {
  return `${SESSION_KEY_PREFIX}:${stepOrder}`;
}

function toCount(value: unknown) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? Math.max(0, Math.trunc(parsed)) : 0;
}

function parseSession(raw: string | null): PlaySession {
  if (!raw) return emptySession;
  try {
    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== "object" || parsed === null) return emptySession;
    const record = parsed as Record<string, unknown>;
    const combo = toCount(record.combo);
    return {
      answered: toCount(record.answered),
      correct: toCount(record.correct),
      combo,
      bestCombo: Math.max(combo, toCount(record.bestCombo)),
    };
  } catch {
    return emptySession;
  }
}

export async function readSession(
  stepOrder: number,
  storage: SessionStorage = AsyncStorage,
): Promise<PlaySession> {
  try {
    return parseSession(await storage.getItem(sessionKey(stepOrder)));
  } catch {
    return emptySession;
  }
}

export async function writeSession(
  stepOrder: number,
  session: PlaySession,
  storage: SessionStorage = AsyncStorage,
) {
  try {
    await storage.setItem(sessionKey(stepOrder), JSON.stringify(session));
    return true;
  } catch {
    return false;
  }
}

export async function resetSession(stepOrder: number, storage: SessionStorage = AsyncStorage) {
  try {
    await storage.removeItem(sessionKey(stepOrder));
  } catch {
    // 저장소 오류가 학습 자체를 막지 않게 한다.
  }
}

export async function recordAnswer(
  stepOrder: number,
  correct: boolean,
  storage: SessionStorage = AsyncStorage,
) {
  const next = applyAnswer(await readSession(stepOrder, storage), correct);
  await writeSession(stepOrder, next, storage);
  return next;
}
