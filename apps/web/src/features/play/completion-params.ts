/**
 * 완주(스텝 한 판 종료) 요약을 URL로 나르는 규약.
 *
 * localStorage 대신 URL을 쓰는 이유는 buildInsightHref(play-page.tsx) 주석 참고.
 * 다만 URL은 브라우저가 만든 값이라 신뢰하지 않는다 — 화면 상한(totalCount)으로 자르고,
 * 팡파레는 한 판에 한 번만 터뜨린다.
 */

const FANFARE_PLAYED_KEY_PREFIX = "thumbsup:completion-fanfare";

export type CompletionSummary = {
  answered: number;
  correct: number;
  bestCombo: number;
};

export type CompletionSearchParams = {
  done?: string;
  /** correct — 맞힌 수 */
  c?: string;
  /** bestCombo — 최고 콤보 */
  bc?: string;
  /** answered — 채점한 수 */
  a?: string;
};

function toCount(value: string | undefined): number {
  const parsed = Number(value);

  return Number.isFinite(parsed) ? Math.max(0, Math.trunc(parsed)) : 0;
}

export function parseCompletion(
  params: CompletionSearchParams | undefined,
): CompletionSummary | null {
  if (params?.done !== "1") {
    return null;
  }

  return {
    answered: toCount(params.a),
    correct: toCount(params.c),
    bestCombo: toCount(params.bc),
  };
}

/** 조작된 URL이 "999문제 정답" 같은 화면을 만들지 못하게 상한으로 자른다. */
export function clampCompletion(summary: CompletionSummary, totalCount: number): CompletionSummary {
  const cap = Math.max(0, Math.trunc(totalCount));

  return {
    answered: Math.min(summary.answered, cap),
    correct: Math.min(summary.correct, cap),
    bestCombo: Math.min(summary.bestCombo, cap),
  };
}

export function isPerfectCompletion(summary: CompletionSummary, totalCount: number): boolean {
  return totalCount > 0 && summary.correct >= totalCount;
}

// sessionStorage도 프라이빗 모드에서 던질 수 있다. 실패하면 "아직 안 봤다"로 취급한다 —
// 최악의 경우 팡파레가 한 번 더 뜰 뿐이고, 그게 화면을 막는 것보다 낫다.
function fanfareKey(key: string) {
  return `${FANFARE_PLAYED_KEY_PREFIX}:${key}`;
}

export function hasPlayedCompletionFanfare(key: string): boolean {
  try {
    return window.sessionStorage.getItem(fanfareKey(key)) !== null;
  } catch {
    return false;
  }
}

export function markCompletionFanfarePlayed(key: string) {
  try {
    window.sessionStorage.setItem(fanfareKey(key), "1");
  } catch {
    /* 위 주석 참고 */
  }
}
