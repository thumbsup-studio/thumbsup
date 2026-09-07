/**
 * 채점 결과 하나를 "어떤 연출을 줄 것인가"로 바꾼다.
 *
 * DOM·타이머·라이브러리를 모르는 순수 함수다 — 연출 규칙이 바뀌어도
 * 여기 테스트만 고치면 되고, 표현 계층은 결과만 받아 그린다.
 *
 * 강도는 매번 크게가 아니라 콤보에 따라 계단식으로 올린다(PopCap celebration hierarchy).
 * 매 정답마다 컨페티가 터지면 며칠 안에 무감각해지고, PRODUCT.md가 금지한
 * "듀오링고 아류식 과다 장식"이 된다.
 */

import type { QuizDifficulty } from "@/lib/api/quiz";

export type CelebrationTier = "none" | "subtle" | "combo" | "confetti";

type CorrectTier = Exclude<CelebrationTier, "none">;

export type Celebration = {
  tier: CelebrationTier;
  /** 오버레이에 띄울 한 줄 문구 */
  praise: string;
  /** 콤보 칩에 쓸 숫자. 표현 계층은 2 이상일 때만 칩을 그린다. */
  comboCount: number;
  /** 콤보와 별개 축으로 붙는 맥락 배지 */
  badge: string | null;
  /** 해설로 자동 이동하기 전 유지 시간(ms). 0이면 타이머 없이 즉시 넘긴다. */
  holdMs: number;
};

export type CelebrationInput = {
  correct: boolean;
  /** 이 답까지 반영한 연속 정답 수. 일반 학습은 PlaySession.combo, 복습은 ReviewContext.streak. */
  combo: number;
  difficulty: QuizDifficulty;
  /** 재도전(#63)으로 다시 풀어 맞혔는지 */
  wasRetry: boolean;
  /** 문구를 결정적으로 고르기 위한 시드 */
  quizId: number;
  prefersReducedMotion: boolean;
};

const HARD_BADGE = "난이도 상 정복";
const RETRY_BADGE = "다시 잡았어요";

// PRODUCT.md 톤: "옆자리 선배 개발자가 엄지 척" — 구호처럼 들리는 표현은 쓰지 않는다.
const PRAISE_BY_TIER: Record<CorrectTier, readonly string[]> = {
  subtle: ["정확해요", "잘 짚었어요", "바로 그거예요", "깔끔하네요"],
  combo: ["연속으로 맞히고 있어요", "감 잡았네요", "속도가 붙었어요"],
  confetti: ["완전히 이해했네요", "실무에서도 통하겠어요", "이 구간은 확실하네요"],
};

const HARD_PRAISE = ["어려운 걸 맞혔어요", "이건 진짜 까다로운 문제였어요", "상 난이도를 넘었어요"];
const RETRY_PRAISE = ["두 번째에 잡았네요", "다시 보니 보이죠", "포기 안 한 게 정답"];
// 오답 문구는 응원에 머문다 — PRODUCT.md 톤: "훈계하거나 과장된 문구를 쓰지 않는다".
const WRONG_PRAISE = [
  "괜찮아요, 여기가 핵심이에요",
  "이 문제는 원래 헷갈려요",
  "지금 짚고 가면 돼요",
];

const HOLD_MS: Record<CelebrationTier, number> = {
  none: 400,
  subtle: 500,
  combo: 700,
  confetti: 1000,
};

/** quizId를 시드로 고른다 — 리렌더에 문구가 바뀌지 않고 테스트도 결정적이다. */
function pick(pool: readonly string[], seed: number): string {
  return pool[Math.abs(Math.trunc(seed)) % pool.length] ?? "";
}

function getBaseTier(combo: number): CorrectTier {
  if (combo >= 3) {
    return "confetti";
  }

  return combo === 2 ? "combo" : "subtle";
}

export function getCelebration(input: CelebrationInput): Celebration {
  if (!input.correct) {
    return {
      tier: "none",
      praise: pick(WRONG_PRAISE, input.quizId),
      comboCount: 0,
      badge: null,
      holdMs: input.prefersReducedMotion ? 0 : HOLD_MS.none,
    };
  }

  // 재도전 성공이 난이도보다 드문 사건이라 배지를 먼저 가져간다.
  const badge = input.wasRetry ? RETRY_BADGE : input.difficulty === "HARD" ? HARD_BADGE : null;

  const baseTier = getBaseTier(input.combo);
  // 배지가 붙는 순간은 콤보가 낮아도 밋밋하게 넘기지 않는다.
  const earnedTier: CorrectTier = badge !== null && baseTier === "subtle" ? "combo" : baseTier;
  // 모션을 끈 사용자에게는 사다리를 올리지 않는다. 문구·배지는 그대로 둔다.
  const tier: CorrectTier = input.prefersReducedMotion ? "subtle" : earnedTier;

  const praisePool = input.wasRetry
    ? RETRY_PRAISE
    : input.difficulty === "HARD"
      ? HARD_PRAISE
      : PRAISE_BY_TIER[earnedTier];

  return {
    tier,
    praise: pick(praisePool, input.quizId),
    comboCount: input.combo,
    badge,
    holdMs: input.prefersReducedMotion ? 0 : HOLD_MS[tier],
  };
}
