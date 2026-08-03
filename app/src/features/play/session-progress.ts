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

/** 저장에 성공했는지 돌려준다 — 구키를 지워도 되는지 판단하는 쪽이 알아야 한다. */
function safeSet(key: string, value: string): boolean {
  try {
    window.localStorage.setItem(key, value);

    return true;
  } catch {
    /* 위 주석 참고 */
    return false;
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

/** 구키를 읽어 세션 형태로 바꾼다 — 지우는 건 새 키에 옮겨 적은 쪽이 판단한다. */
function readLegacy(stepOrder: number): PlaySession | null {
  const raw = safeGet(legacyKey(stepOrder));
  if (raw === null) {
    return null;
  }

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

  const migrated = readLegacy(stepOrder);
  if (migrated !== null) {
    // 새 키에 옮겨 적는 데 성공했을 때만 구키를 지운다. 순서를 뒤집으면 저장이 실패한 순간
    // 유일한 사본이 사라져 콤보가 영구 소실된다(사파리 프라이빗 모드·쿼터 초과).
    if (writeSession(stepOrder, migrated)) {
      safeRemove(legacyKey(stepOrder));
    }

    return migrated;
  }

  return emptySession;
}

/** 저장 성공 여부를 돌려준다 — 구키 정리처럼 저장이 실제로 됐는지에 달린 후속 처리가 있다. */
export function writeSession(stepOrder: number, session: PlaySession): boolean {
  return safeSet(sessionKey(stepOrder), JSON.stringify(session));
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
