/**
 * 퀴즈 세션(스텝 한 판)의 누적 진행 상태.
 *
 * 순수 함수(applyAnswer)와 localStorage 접근을 나눠 둔다 —
 * 상태 규칙은 브라우저 없이 검증할 수 있어야 하고, 저장 실패가 규칙을 오염시키면 안 된다.
 * 복습(재풀이)은 이 모듈을 쓰지 않는다: 복습 상태는 URL(rc/rs)로 나른다(review-params.ts).
 */

const SESSION_KEY_PREFIX = "thumbsup:play-session";
/** 이전 형식(숫자 스트릭). 배포 시점에 진행 중이던 세션을 위해 1회만 읽고 지운다. */
const LEGACY_STREAK_KEY_PREFIX = "thumbsup:insight-correct-streak:api-quiz";

export type PlaySession = {
  /** 채점을 마친 문제 수 */
  answered: number;
  /** 맞힌 문제 수 */
  correct: number;
  /** 현재 연속 정답 수 */
  combo: number;
  /** 이번 스텝에서 도달한 최고 연속 정답 수 */
  bestCombo: number;
};

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

function legacyKey(stepOrder: number) {
  return `${LEGACY_STREAK_KEY_PREFIX}:${stepOrder}`;
}

// 사파리 프라이빗 모드·용량 초과에서 localStorage는 던진다.
// 저장이 안 되면 연출 품질만 떨어질 뿐 학습은 계속돼야 하므로 전부 삼킨다.
function safeGet(key: string): string | null {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function safeSet(key: string, value: string) {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    /* 위 주석 참고 */
  }
}

function safeRemove(key: string) {
  try {
    window.localStorage.removeItem(key);
  } catch {
    /* 위 주석 참고 */
  }
}

function toCount(value: unknown): number {
  const parsed = Number(value);

  return Number.isFinite(parsed) ? Math.max(0, Math.trunc(parsed)) : 0;
}

function parseSession(raw: string | null): PlaySession | null {
  if (raw === null) {
    return null;
  }

  try {
    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== "object" || parsed === null) {
      return null;
    }

    const record = parsed as Record<string, unknown>;
    const combo = toCount(record.combo);

    return {
      answered: toCount(record.answered),
      correct: toCount(record.correct),
      combo,
      // 손상된 값이 들어와도 "최고가 현재보다 작은" 모순은 만들지 않는다.
      bestCombo: Math.max(combo, toCount(record.bestCombo)),
    };
  } catch {
    return null;
  }
}

function migrateLegacy(stepOrder: number): PlaySession | null {
  const raw = safeGet(legacyKey(stepOrder));
  if (raw === null) {
    return null;
  }

  safeRemove(legacyKey(stepOrder));
  const combo = toCount(raw);

  // answered·correct는 구키에 없어 복원할 수 없다. 0으로 두면
  // 완주 카드가 `answered === totalCount` 검사에서 걸러 정답 줄을 감춘다 — 틀린 숫자를 보여주지 않는다.
  return { answered: 0, correct: 0, combo, bestCombo: combo };
}

export function readSession(stepOrder: number): PlaySession {
  const stored = parseSession(safeGet(sessionKey(stepOrder)));
  if (stored !== null) {
    return stored;
  }

  // migrateLegacy는 구키를 지우므로 옮겨 적기까지 해야 한 쌍이 된다.
  // 저장하지 않으면 "읽기만 했는데 콤보가 사라지는" 상태가 된다 — 화면 표시용 읽기가 늘면 바로 드러난다.
  const migrated = migrateLegacy(stepOrder);
  if (migrated !== null) {
    writeSession(stepOrder, migrated);
    return migrated;
  }

  return emptySession;
}

export function writeSession(stepOrder: number, session: PlaySession) {
  safeSet(sessionKey(stepOrder), JSON.stringify(session));
}

export function resetSession(stepOrder: number) {
  safeRemove(legacyKey(stepOrder));
  writeSession(stepOrder, emptySession);
}

/** 채점 결과를 반영해 저장하고 갱신된 세션을 돌려준다. */
export function recordAnswer(stepOrder: number, correct: boolean): PlaySession {
  const next = applyAnswer(readSession(stepOrder), correct);
  writeSession(stepOrder, next);

  return next;
}
