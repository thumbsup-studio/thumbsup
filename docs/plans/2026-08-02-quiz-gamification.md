# 퀴즈 게이미피케이션 구현 계획 (#211 · #197)

> **For agentic workers:** 이 계획은 태스크 단위로 순서대로 실행한다. 각 스텝의 체크박스(`- [ ]`)를 진행 표시에 쓴다. 스텝은 "실패 테스트 작성 → 실패 확인 → 최소 구현 → 통과 확인 → 커밋" 순서를 그대로 지킨다.

**설계 정본:** [`docs/specs/2026-08-02-quiz-gamification-design.md`](../specs/2026-08-02-quiz-gamification-design.md) — 이 계획과 충돌하면 **스펙이 우선**이다.

**Goal:** 퀴즈 화면(S3)에 정답 판정 순간의 연출을 넣고, 콤보가 쌓일수록 커지는 단계형 에스컬레이션과 완주 요약 카드를 붙인다.

**Architecture:** 상태(`session-progress`) · 결정(`celebration-logic`) · 표현(`celebration-overlay`) 3계층으로 가른다. 앞의 둘은 순수 함수라 브라우저 없이 테스트하고, 애니메이션 라이브러리는 표현 계층 한 곳에만 갇힌다.

**Tech Stack:** Next.js 16 App Router · React 19 · TypeScript strict · Tailwind CSS v4 (`@theme` 토큰) · Vitest + Testing Library · Biome · `canvas-confetti`(신규) · `@lottiefiles/dotlottie-react`(기존)

## Global Constraints

- **작업 디렉터리는 `app/`.** 모든 `pnpm` 명령은 `app/`에서 실행한다.
- **브랜치는 `feat/211-quiz-gamification`.** `main`에 직접 커밋 금지. push 금지 — 커밋까지만 한다.
- **스타일은 `globals.css @theme` 토큰과 `src/components/ui` 컴포넌트만 쓴다.** raw hex(`#2f63ff`)와 Tailwind arbitrary value(`bg-[#fff]`, `rounded-[36px]`) 금지 — `pnpm check:design`이 소스 전체를 정규식으로 막는다.
- **주석은 한국어.** 무엇을 하는지가 아니라 **왜 그렇게 했는지**를 쓴다. 기존 코드의 주석 밀도에 맞춘다.
- **커밋 메시지 형식:** `<type>(app): <한국어 요약> (#211)`. 끝에 `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>` 붙이지 말 것 — Codex가 작성하는 커밋이다.
- **`import` alias는 `@/*` → `src/*`.**
- **파일명은 kebab-case.**
- **테스트 파일 위치는 `src/test/`** (기존 관례 — 소스 옆이 아니다).
- 각 태스크 끝에서 **`pnpm typecheck && pnpm lint && pnpm test`** 가 그린이어야 커밋한다.
- **`5`를 하드코딩하지 않는다.** 세션 문제 수는 `QuizNextResponse.totalCount`(옵셔널)이고 없으면 `defaultStepTotal`(5)로 fallback하는 기존 규칙을 따른다.

---

## 파일 구조

| 파일 | 책임 | 태스크 |
|---|---|---|
| `src/features/play/session-progress.ts` (신규) | 세션 누적 상태 + localStorage 영속화 + 구키 마이그레이션 | 1 |
| `src/test/session-progress.test.ts` (신규) | 위 검증 | 1 |
| `src/features/play/celebration-logic.ts` (신규) | 결과 → 연출 등급·문구·유지시간 결정 (순수) | 2 |
| `src/test/celebration-logic.test.ts` (신규) | 위 검증 | 2 |
| `src/features/play/use-prefers-reduced-motion.ts` (신규) | OS 모션 줄이기 감지 | 3 |
| `src/test/setup.ts` (수정) | `matchMedia` 목 추가 | 3 |
| `src/app/globals.css` (수정) | 팝·바운스 keyframes + reduced-motion 전역 가드 | 3 |
| `src/features/play/components/celebration-overlay.tsx` (신규) | 판정 오버레이 렌더 + 컨페티 | 4 |
| `src/features/play/components/celebration-overlay.stories.tsx` (신규) | 강도 튜닝용 스토리 | 4 |
| `src/features/play/components/play-page.tsx` (수정) | 오버레이 연결·지연 라우팅·중복 push 차단 | 5 |
| `src/test/play-page.test.tsx` (수정) | 기존 9개 라우팅 단언 마이그레이션 + 신규 검증 | 5 |
| `src/features/play/completion-params.ts` (신규) | 완주 URL 파싱·clamp·퍼펙트 판정·팡파레 1회 가드 | 6 |
| `src/test/completion-params.test.ts` (신규) | 위 검증 | 6 |
| `src/app/insight/page.tsx` (수정) | 완주 파라미터 파싱 | 6 |
| `src/features/play/components/completion-card.tsx` (신규) | 완주 요약 카드 | 7 |
| `src/features/play/components/fanfare-overlay.tsx` (신규) | insight-page에서 추출, 복습 요약과 공유 | 8 |
| `src/features/play/components/insight-page.tsx` (수정) | 완주 카드 렌더 + 팡파레 조건 교체 | 7·8 |
| `src/features/history/components/review-summary-page.tsx` (수정) | 퍼펙트 팡파레 추가 | 8 |
| `src/test/insight-page.test.tsx` (수정) | 팡파레 5묶음 재작성 + 완주 카드 검증 | 7·8 |

---

## Task 1: 세션 진행 상태

**Files:**
- Create: `app/src/features/play/session-progress.ts`
- Test: `app/src/test/session-progress.test.ts`

**Interfaces:**
- Consumes: 없음
- Produces: `type PlaySession = { answered: number; correct: number; combo: number; bestCombo: number }` · `emptySession: PlaySession` · `applyAnswer(session: PlaySession, correct: boolean): PlaySession` · `readSession(stepOrder: number): PlaySession` · `resetSession(stepOrder: number): void` · `recordAnswer(stepOrder: number, correct: boolean): PlaySession`

- [ ] **Step 1: 실패 테스트 작성**

`app/src/test/session-progress.test.ts`:

```ts
import { beforeEach, describe, expect, it } from "vitest";
import {
  applyAnswer,
  emptySession,
  readSession,
  recordAnswer,
  resetSession,
} from "@/features/play/session-progress";

describe("applyAnswer", () => {
  it("정답이면 콤보와 정답 수를 함께 올린다", () => {
    const result = applyAnswer({ answered: 1, correct: 1, combo: 1, bestCombo: 1 }, true);

    expect(result).toEqual({ answered: 2, correct: 2, combo: 2, bestCombo: 2 });
  });

  it("오답이면 콤보만 0으로 만들고 최고 콤보는 남긴다", () => {
    const result = applyAnswer({ answered: 3, correct: 3, combo: 3, bestCombo: 3 }, false);

    expect(result).toEqual({ answered: 4, correct: 3, combo: 0, bestCombo: 3 });
  });

  it("콤보가 다시 오르되 이전 최고를 넘지 못하면 최고 콤보는 그대로다", () => {
    const result = applyAnswer({ answered: 4, correct: 3, combo: 0, bestCombo: 3 }, true);

    expect(result.bestCombo).toBe(3);
    expect(result.combo).toBe(1);
  });
});

describe("세션 영속화", () => {
  beforeEach(() => {
    window.localStorage.clear();
  });

  it("저장된 세션이 없으면 빈 세션을 돌려준다", () => {
    expect(readSession(1)).toEqual(emptySession);
  });

  it("채점 결과를 저장하고 다음 읽기에서 이어받는다", () => {
    recordAnswer(2, true);
    recordAnswer(2, true);

    expect(readSession(2)).toEqual({ answered: 2, correct: 2, combo: 2, bestCombo: 2 });
  });

  it("스텝마다 세션을 따로 보관한다", () => {
    recordAnswer(1, true);

    expect(readSession(2)).toEqual(emptySession);
  });

  it("resetSession은 세션을 비운다", () => {
    recordAnswer(3, true);
    resetSession(3);

    expect(readSession(3)).toEqual(emptySession);
  });

  it("구키(숫자 스트릭)를 콤보로 옮기고 구키를 지운다", () => {
    window.localStorage.setItem("thumbsup:insight-correct-streak:api-quiz:4", "3");

    // answered·correct는 구키에 없어 복원할 수 없다 — 완주 카드가 정답 줄을 감추는 근거.
    expect(readSession(4)).toEqual({ answered: 0, correct: 0, combo: 3, bestCombo: 3 });
    expect(window.localStorage.getItem("thumbsup:insight-correct-streak:api-quiz:4")).toBeNull();
  });

  it("깨진 JSON이 저장돼 있어도 빈 세션으로 복구한다", () => {
    window.localStorage.setItem("thumbsup:play-session:5", "{not json");

    expect(readSession(5)).toEqual(emptySession);
  });

  it("음수·소수가 저장돼 있어도 0 이상 정수로 정규화한다", () => {
    window.localStorage.setItem(
      "thumbsup:play-session:6",
      JSON.stringify({ answered: -2, correct: 1.7, combo: 2, bestCombo: 1 }),
    );

    // bestCombo가 combo보다 작게 저장돼 있으면 combo로 끌어올린다.
    expect(readSession(6)).toEqual({ answered: 0, correct: 1, combo: 2, bestCombo: 2 });
  });
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd app && pnpm vitest run src/test/session-progress.test.ts`
Expected: FAIL — `Failed to resolve import "@/features/play/session-progress"`

- [ ] **Step 3: 최소 구현**

`app/src/features/play/session-progress.ts`:

```ts
/**
 * 퀴즈 세션(스텝 한 판)의 누적 진행 상태.
 *
 * 순수 함수(applyAnswer)와 localStorage 접근을 나눠 둔다 —
 * 상태 규칙은 브라우저 없이 검증할 수 있어야 하고, 저장 실패가 규칙을 오염시키면 안 된다.
 * 복습(재풀이)은 이 모듈을 쓰지 않는다: 복습 상태는 URL(rc/rs)로 나른다(review-params.ts).
 */

const SESSION_KEY_PREFIX = "thumbsup:play-session";
/** #211 이전 형식(숫자 스트릭). 배포 시점에 진행 중이던 세션을 위해 1회만 읽고 지운다. */
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
  return parseSession(safeGet(sessionKey(stepOrder))) ?? migrateLegacy(stepOrder) ?? emptySession;
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
```

- [ ] **Step 4: 통과 확인**

Run: `cd app && pnpm vitest run src/test/session-progress.test.ts`
Expected: PASS (11 tests)

- [ ] **Step 5: 커밋**

```bash
cd app && pnpm typecheck && pnpm lint && cd ..
git add app/src/features/play/session-progress.ts app/src/test/session-progress.test.ts
git commit -m "feat(app): 퀴즈 세션 진행 상태 모듈 — 콤보·최고콤보·구키 마이그레이션 (#211)"
```

---

## Task 2: 연출 결정 로직

**Files:**
- Create: `app/src/features/play/celebration-logic.ts`
- Test: `app/src/test/celebration-logic.test.ts`

**Interfaces:**
- Consumes: `QuizDifficulty` from `@/lib/api/quiz`
- Produces: `type CelebrationTier = "none" | "subtle" | "combo" | "confetti"` · `type Celebration = { tier: CelebrationTier; praise: string; comboCount: number; badge: string | null; holdMs: number }` · `type CelebrationInput = { correct: boolean; combo: number; difficulty: QuizDifficulty; wasRetry: boolean; quizId: number; prefersReducedMotion: boolean }` · `getCelebration(input: CelebrationInput): Celebration`

- [ ] **Step 1: 실패 테스트 작성**

`app/src/test/celebration-logic.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import {
  type CelebrationInput,
  getCelebration,
} from "@/features/play/celebration-logic";

function input(overrides: Partial<CelebrationInput> = {}): CelebrationInput {
  return {
    combo: 1,
    correct: true,
    difficulty: "EASY",
    prefersReducedMotion: false,
    quizId: 7,
    wasRetry: false,
    ...overrides,
  };
}

describe("getCelebration — 콤보 사다리", () => {
  it("1콤보는 subtle", () => {
    expect(getCelebration(input({ combo: 1 })).tier).toBe("subtle");
  });

  it("2콤보는 combo", () => {
    expect(getCelebration(input({ combo: 2 })).tier).toBe("combo");
  });

  it("3콤보부터 confetti", () => {
    expect(getCelebration(input({ combo: 3 })).tier).toBe("confetti");
    expect(getCelebration(input({ combo: 9 })).tier).toBe("confetti");
  });

  it("콤보 칩은 2부터 그린다 — 1콤보에 \"1콤보\"는 어색하다", () => {
    expect(getCelebration(input({ combo: 1 })).comboCount).toBe(1);
    expect(getCelebration(input({ combo: 2 })).comboCount).toBe(2);
  });

  it("등급이 올라갈수록 유지 시간이 길어진다", () => {
    const subtle = getCelebration(input({ combo: 1 })).holdMs;
    const combo = getCelebration(input({ combo: 2 })).holdMs;
    const confetti = getCelebration(input({ combo: 3 })).holdMs;

    expect(subtle).toBeLessThan(combo);
    expect(combo).toBeLessThan(confetti);
  });
});

describe("getCelebration — 맥락 배지", () => {
  it("난이도 상 정답에 배지를 붙인다", () => {
    expect(getCelebration(input({ difficulty: "HARD" })).badge).toBe("난이도 상 정복");
  });

  it("재도전 성공에 배지를 붙인다", () => {
    expect(getCelebration(input({ wasRetry: true })).badge).toBe("다시 잡았어요");
  });

  it("재도전 배지가 난이도 배지보다 우선한다", () => {
    expect(getCelebration(input({ difficulty: "HARD", wasRetry: true })).badge).toBe(
      "다시 잡았어요",
    );
  });

  it("배지가 있으면 1콤보라도 subtle에서 combo로 올린다", () => {
    expect(getCelebration(input({ combo: 1, difficulty: "HARD" })).tier).toBe("combo");
  });

  it("배지가 있어도 3콤보 이상이면 confetti 그대로", () => {
    expect(getCelebration(input({ combo: 3, difficulty: "HARD" })).tier).toBe("confetti");
  });

  it("일반 난이도 정답에는 배지가 없다", () => {
    expect(getCelebration(input({ difficulty: "MEDIUM" })).badge).toBeNull();
  });
});

describe("getCelebration — 오답", () => {
  it("오답은 tier none이고 배지·콤보 칩이 없다", () => {
    const result = getCelebration(input({ combo: 0, correct: false, difficulty: "HARD" }));

    expect(result.tier).toBe("none");
    expect(result.badge).toBeNull();
    expect(result.comboCount).toBe(0);
  });

  it("오답 문구는 응원조이고 콤보가 끊긴 걸 지적하지 않는다", () => {
    const result = getCelebration(input({ combo: 0, correct: false }));

    expect(result.praise.length).toBeGreaterThan(0);
    expect(result.praise).not.toMatch(/콤보|연속|끊/);
  });
});

describe("getCelebration — 문구 결정성", () => {
  it("같은 입력이면 같은 문구를 고른다", () => {
    expect(getCelebration(input({ quizId: 42 })).praise).toBe(
      getCelebration(input({ quizId: 42 })).praise,
    );
  });

  it("quizId가 다르면 문구가 갈린다", () => {
    const praises = [1, 2, 3, 4].map((quizId) => getCelebration(input({ quizId })).praise);

    expect(new Set(praises).size).toBeGreaterThan(1);
  });
});

describe("getCelebration — 모션 줄이기", () => {
  it("holdMs를 0으로 만들어 즉시 넘어가게 한다", () => {
    expect(getCelebration(input({ combo: 3, prefersReducedMotion: true })).holdMs).toBe(0);
    expect(
      getCelebration(input({ correct: false, prefersReducedMotion: true })).holdMs,
    ).toBe(0);
  });

  it("등급을 subtle로 눌러 컨페티가 안 터지게 한다", () => {
    expect(getCelebration(input({ combo: 5, prefersReducedMotion: true })).tier).toBe("subtle");
  });

  it("오답은 모션을 꺼도 none 그대로다", () => {
    expect(
      getCelebration(input({ correct: false, prefersReducedMotion: true })).tier,
    ).toBe("none");
  });

  it("문구와 배지는 모션과 무관하게 유지한다", () => {
    const result = getCelebration(input({ combo: 5, difficulty: "HARD", prefersReducedMotion: true }));

    expect(result.badge).toBe("난이도 상 정복");
    expect(result.comboCount).toBe(5);
  });
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd app && pnpm vitest run src/test/celebration-logic.test.ts`
Expected: FAIL — `Failed to resolve import "@/features/play/celebration-logic"`

- [ ] **Step 3: 최소 구현**

`app/src/features/play/celebration-logic.ts`:

```ts
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

const PRAISE_BY_TIER: Record<CorrectTier, readonly string[]> = {
  subtle: ["정확해요", "잘 짚었어요", "바로 그거예요", "깔끔하네요"],
  combo: ["연속으로 맞히고 있어요", "감 잡았네요", "리듬 탔어요", "속도가 붙었어요"],
  confetti: ["흐름 타네요", "완전히 이해했네요", "실무에서도 통하겠어요", "멈출 줄을 모르네요"],
};

const HARD_PRAISE = ["어려운 걸 맞혔어요", "이건 진짜 까다로운 문제였어요", "상 난이도를 넘었어요"];
const RETRY_PRAISE = ["두 번째에 잡았네요", "다시 보니 보이죠", "포기 안 한 게 정답"];
// 오답 문구는 응원에 머문다 — PRODUCT.md 톤: "훈계하거나 과장된 문구를 쓰지 않는다".
const WRONG_PRAISE = ["괜찮아요, 여기가 핵심이에요", "이 문제는 원래 헷갈려요", "지금 짚고 가면 돼요"];

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
```

- [ ] **Step 4: 통과 확인**

Run: `cd app && pnpm vitest run src/test/celebration-logic.test.ts`
Expected: PASS (18 tests)

- [ ] **Step 5: 커밋**

```bash
cd app && pnpm typecheck && pnpm lint && cd ..
git add app/src/features/play/celebration-logic.ts app/src/test/celebration-logic.test.ts
git commit -m "feat(app): 정답 연출 결정 로직 — 콤보 사다리·맥락 배지·문구 다양화 (#211, #197)"
```

---

## Task 3: 모션 인프라

**Files:**
- Create: `app/src/features/play/use-prefers-reduced-motion.ts`
- Modify: `app/src/test/setup.ts` (끝에 추가)
- Modify: `app/src/app/globals.css:53-71`(애니메이션 블록 뒤) · 파일 끝

**Interfaces:**
- Consumes: 없음
- Produces: `usePrefersReducedMotion(): boolean` · CSS 유틸 클래스 `animate-celebration-pop`·`animate-combo-bounce` · 테스트 전역 `window.matchMedia` 목(기본 `matches: false`)

- [ ] **Step 1: 훅 작성**

`app/src/features/play/use-prefers-reduced-motion.ts`:

```ts
"use client";

import { useEffect, useState } from "react";

const REDUCED_MOTION_QUERY = "(prefers-reduced-motion: reduce)";

/**
 * OS의 "모션 줄이기" 설정을 읽는다.
 *
 * SSR과 jsdom에는 matchMedia가 없으므로 false(모션 허용)로 시작하고 마운트 후 맞춘다.
 * 첫 렌더에서 값이 틀려도 문제가 없는 이유: 이 값은 사용자가 [정답 확인]을 누른 뒤에야
 * 쓰이는데, 그 시점엔 이미 이펙트가 돌아 실제 값이 들어와 있다.
 */
export function usePrefersReducedMotion(): boolean {
  const [prefersReducedMotion, setPrefersReducedMotion] = useState(false);

  useEffect(() => {
    if (typeof window.matchMedia !== "function") {
      return undefined;
    }

    const mediaQuery = window.matchMedia(REDUCED_MOTION_QUERY);
    setPrefersReducedMotion(mediaQuery.matches);

    function handleChange(event: MediaQueryListEvent) {
      setPrefersReducedMotion(event.matches);
    }

    mediaQuery.addEventListener("change", handleChange);

    return () => {
      mediaQuery.removeEventListener("change", handleChange);
    };
  }, []);

  return prefersReducedMotion;
}
```

- [ ] **Step 2: 테스트 setup에 matchMedia 목 추가**

`app/src/test/setup.ts` — `globalThis.ResizeObserver = MockResizeObserver;` 아래, `afterEach` 위에 삽입:

```ts
/**
 * jsdom에는 matchMedia가 없다. 기본값은 `matches: false`(모션 허용) —
 * 실제 사용자 대부분이 그렇고, 모션을 끈 경로는 각 테스트가 명시적으로 덮어쓴다.
 */
function createMatchMedia(matches: boolean) {
  return (query: string): MediaQueryList =>
    ({
      addEventListener: () => {},
      addListener: () => {},
      dispatchEvent: () => false,
      matches,
      media: query,
      onchange: null,
      removeEventListener: () => {},
      removeListener: () => {},
    }) as MediaQueryList;
}

/** 테스트에서 모션 줄이기 상태를 바꿀 때 쓴다. */
export function setPrefersReducedMotion(matches: boolean) {
  window.matchMedia = createMatchMedia(matches);
}

setPrefersReducedMotion(false);

afterEach(() => {
  setPrefersReducedMotion(false);
});
```

> ⚠️ 기존 파일 끝의 `afterEach(() => { cleanup(); });` 는 그대로 둔다. `afterEach`가 두 번 등록되어도 vitest는 둘 다 실행한다.

- [ ] **Step 3: globals.css에 keyframes와 reduced-motion 가드 추가**

`app/src/app/globals.css` — `@keyframes overlay-fade { ... }` 블록 **뒤**, `@theme`을 닫는 `}` **앞**에 삽입:

```css
  /* 정답 판정 연출(#211) — 체크 팝 · 콤보/배지 칩 바운스 */
  --animate-celebration-pop: celebration-pop 0.42s cubic-bezier(0.34, 1.56, 0.64, 1);
  --animate-combo-bounce: combo-bounce 0.5s cubic-bezier(0.34, 1.56, 0.64, 1);
  @keyframes celebration-pop {
    from {
      opacity: 0;
      transform: scale(0.72);
    }
    to {
      opacity: 1;
      transform: scale(1);
    }
  }
  @keyframes combo-bounce {
    0% {
      opacity: 0;
      transform: translateY(0.5rem) scale(0.8);
    }
    60% {
      opacity: 1;
      transform: translateY(-0.25rem) scale(1.08);
    }
    100% {
      opacity: 1;
      transform: translateY(0) scale(1);
    }
  }
```

그리고 **파일 맨 끝**(`body { ... }` 아래)에 추가:

```css
/*
 * 모션 줄이기를 켠 사용자에겐 애니메이션을 사실상 끈다.
 * 연출 등급·유지 시간은 celebration-logic이 이미 눌러 두지만,
 * CSS 애니메이션은 JS를 거치지 않으므로 여기서 한 번 더 막는다.
 * 바텀시트 등 기존 애니메이션에도 함께 적용된다 — 의도한 개선이다.
 */
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

- [ ] **Step 4: 게이트 확인**

Run: `cd app && pnpm typecheck && pnpm lint && pnpm check:design && pnpm test`
Expected: 전부 PASS. `check:design`은 "✅ 위반 없음" — `cubic-bezier(...)`는 arbitrary value 정규식(`-[...]`)에도 hex에도 걸리지 않는다.

- [ ] **Step 5: 커밋**

```bash
git add app/src/features/play/use-prefers-reduced-motion.ts app/src/test/setup.ts app/src/app/globals.css
git commit -m "feat(app): 정답 연출용 모션 토큰·모션 줄이기 감지 (#211)"
```

---

## Task 4: 판정 오버레이

**Files:**
- Create: `app/src/features/play/components/celebration-overlay.tsx`
- Create: `app/src/features/play/components/celebration-overlay.stories.tsx`
- Modify: `app/package.json` (의존성 추가)

**Interfaces:**
- Consumes: `Celebration` (Task 2) · `Chip` from `@/components/ui/chip` · `CheckIcon`·`AlertCircleIcon` from `@/components/icons`
- Produces: `<CelebrationOverlay celebration={Celebration} onContinue={() => void} />`

- [ ] **Step 1: 의존성 추가**

```bash
cd app && pnpm add canvas-confetti@1.9.3 && pnpm add -D @types/canvas-confetti@1.9.0
```

설치 후 `pnpm why canvas-confetti`로 실제 버전을 확인하고, 위 버전이 없으면 최신 1.x를 쓴다. 라이선스는 ISC.

- [ ] **Step 2: 오버레이 구현**

`app/src/features/play/components/celebration-overlay.tsx`:

```tsx
"use client";

import { useEffect, useRef } from "react";
import { AlertCircleIcon, CheckIcon } from "@/components/icons";
import { Chip } from "@/components/ui/chip";
import type { Celebration } from "@/features/play/celebration-logic";

/**
 * 컨페티 색은 globals.css @theme 토큰에서 런타임에 읽는다.
 * 소스에 raw hex를 넣으면 check:design 게이트가 막고, 토큰이 바뀌어도 연출이 따라오지 않는다.
 */
const CONFETTI_COLOR_TOKENS = ["--color-primary", "--color-accent", "--color-ox-o"] as const;

function readTokenColors(): string[] {
  const styles = getComputedStyle(document.documentElement);

  return CONFETTI_COLOR_TOKENS.map((token) => styles.getPropertyValue(token).trim()).filter(
    (color) => color.length > 0,
  );
}

async function fireConfetti() {
  // 토큰을 못 읽으면 컨페티를 생략한다 — 하드코딩 색으로 때우지 않는다.
  const colors = readTokenColors();
  if (colors.length === 0) {
    return;
  }

  try {
    const { default: confetti } = await import("canvas-confetti");
    confetti({
      colors,
      disableForReducedMotion: true,
      origin: { x: 0.5, y: 0.62 },
      particleCount: 60,
      spread: 70,
      startVelocity: 32,
      ticks: 120,
    });
  } catch {
    // 지연 로드 실패는 연출만 생략한다 — 채점 흐름을 막으면 안 된다.
  }
}

type CelebrationOverlayProps = {
  celebration: Celebration;
  /** 유지 시간을 기다리지 않고 해설로 넘어간다. 중복 호출은 호출부가 막는다. */
  onContinue: () => void;
};

export function CelebrationOverlay({ celebration, onContinue }: CelebrationOverlayProps) {
  const hasFiredConfetti = useRef(false);

  useEffect(() => {
    if (celebration.tier !== "confetti" || hasFiredConfetti.current) {
      return;
    }

    // StrictMode가 이펙트를 두 번 돌려도 컨페티는 한 번만 터뜨린다.
    hasFiredConfetti.current = true;
    void fireConfetti();
  }, [celebration.tier]);

  const isCorrect = celebration.tier !== "none";

  return (
    <div
      className="fixed inset-0 z-50 flex items-end justify-center bg-ink/20 px-4 pb-6"
      data-testid="celebration-overlay"
      data-tier={celebration.tier}
    >
      <div
        aria-live="polite"
        className="flex w-full max-w-md animate-celebration-pop flex-col items-center gap-3 rounded-card border border-border bg-surface px-5 py-6 shadow-card"
        role="status"
      >
        {/* 색만으로 정오답을 구분하지 않는다 — 아이콘과 문구를 항상 함께 낸다. */}
        <span
          className={`grid h-14 w-14 place-items-center rounded-chip ${
            isCorrect ? "bg-success/10 text-success" : "bg-danger/10 text-danger"
          }`}
        >
          {isCorrect ? (
            <CheckIcon className="h-7 w-7" />
          ) : (
            <AlertCircleIcon className="h-7 w-7" />
          )}
        </span>

        <p className="text-center text-base font-black text-ink">{celebration.praise}</p>

        {celebration.badge !== null || celebration.comboCount >= 2 ? (
          <div className="flex flex-wrap items-center justify-center gap-2">
            {celebration.badge !== null ? (
              <Chip className="animate-combo-bounce" tone="primary">
                {celebration.badge}
              </Chip>
            ) : null}
            {/* 1콤보에 "1콤보"는 어색하므로 2부터 그린다. */}
            {celebration.comboCount >= 2 ? (
              <Chip className="animate-combo-bounce" tone="success">
                {celebration.comboCount}콤보
              </Chip>
            ) : null}
          </div>
        ) : null}

        <button
          className="mt-1 flex min-h-12 w-full items-center justify-center rounded-control bg-primary px-5 py-3 font-bold text-primary-fg shadow-hero"
          onClick={onContinue}
          type="button"
        >
          계속
        </button>
      </div>
    </div>
  );
}
```

- [ ] **Step 3: 강도 튜닝용 스토리 작성**

`app/src/features/play/components/celebration-overlay.stories.tsx`:

```tsx
import type { Meta, StoryObj } from "@storybook/nextjs-vite";
import { getCelebration } from "@/features/play/celebration-logic";
import { CelebrationOverlay } from "@/features/play/components/celebration-overlay";

/**
 * #211 완료 기준 3번("학습 흐름을 방해하지 않는 선에서 강도 튜닝")은 글로 정할 수 없다.
 * 이 스토리에서 사다리 각 칸을 반복 재생하며 celebration-logic의 HOLD_MS를 확정한다.
 */
const meta = {
  component: CelebrationOverlay,
  parameters: { layout: "fullscreen" },
  title: "play/CelebrationOverlay",
} satisfies Meta<typeof CelebrationOverlay>;

export default meta;

type Story = StoryObj<typeof meta>;

function celebration(overrides: Parameters<typeof getCelebration>[0]) {
  return getCelebration(overrides);
}

const base = {
  correct: true,
  difficulty: "EASY" as const,
  prefersReducedMotion: false,
  quizId: 7,
  wasRetry: false,
};

export const Combo1: Story = {
  args: { celebration: celebration({ ...base, combo: 1 }), onContinue: () => {} },
};

export const Combo2: Story = {
  args: { celebration: celebration({ ...base, combo: 2 }), onContinue: () => {} },
};

export const Combo3Confetti: Story = {
  args: { celebration: celebration({ ...base, combo: 3 }), onContinue: () => {} },
};

export const HardDifficulty: Story = {
  args: {
    celebration: celebration({ ...base, combo: 1, difficulty: "HARD" }),
    onContinue: () => {},
  },
};

export const RetrySuccess: Story = {
  args: {
    celebration: celebration({ ...base, combo: 2, wasRetry: true }),
    onContinue: () => {},
  },
};

export const Wrong: Story = {
  args: {
    celebration: celebration({ ...base, combo: 0, correct: false }),
    onContinue: () => {},
  },
};

export const ReducedMotion: Story = {
  args: {
    celebration: celebration({ ...base, combo: 5, prefersReducedMotion: true }),
    onContinue: () => {},
  },
};
```

- [ ] **Step 4: 게이트 확인**

Run: `cd app && pnpm typecheck && pnpm lint && pnpm check:design`
Expected: 전부 PASS

- [ ] **Step 5: 커밋**

```bash
git add app/package.json app/pnpm-lock.yaml app/src/features/play/components/celebration-overlay.tsx app/src/features/play/components/celebration-overlay.stories.tsx
git commit -m "feat(app): 정답 판정 오버레이 — 콤보 칩·맥락 배지·컨페티 (#211)"
```

---

## Task 5: 퀴즈 화면 통합

**Files:**
- Modify: `app/src/features/play/components/play-page.tsx`
- Modify: `app/src/test/play-page.test.tsx`

**Interfaces:**
- Consumes: `recordAnswer`·`resetSession`·`PlaySession` (Task 1) · `getCelebration`·`Celebration` (Task 2) · `usePrefersReducedMotion` (Task 3) · `CelebrationOverlay` (Task 4)
- Produces: 완주 시 `/insight?quizId=..&correct=..&streak=..&done=1&c=..&bc=..&a=..` 형태의 URL

### 5-1. 기존 헬퍼 제거와 교체

- [ ] **Step 1: play-page.tsx 상단 정리**

`play-page.tsx:34` 의 `const correctStreakStorageKeyPrefix = ...` 줄을 **삭제**하고, `play-page.tsx:610-630` 의 함수 4개(`getCorrectStreakStorageKey`·`resetCorrectStreak`·`readCorrectStreak`·`updateCorrectStreak`)를 **전부 삭제**한다.

import 블록(`play-page.tsx:1-29`)에 추가:

```ts
import { getCelebration, type Celebration } from "@/features/play/celebration-logic";
import { CelebrationOverlay } from "@/features/play/components/celebration-overlay";
import { recordAnswer, resetSession } from "@/features/play/session-progress";
import { usePrefersReducedMotion } from "@/features/play/use-prefers-reduced-motion";
```

- [ ] **Step 2: 연출·라우팅 상태 추가**

`PlayPage` 컴포넌트 본문에서 `const [hasUsedRetry, setHasUsedRetry] = useState(false);`(`play-page.tsx:57`) **바로 아래**에 삽입:

```ts
  // 채점 결과를 화면에서 먼저 보여준 뒤 해설로 넘긴다(#211).
  const [celebration, setCelebration] = useState<Celebration | null>(null);
  const prefersReducedMotion = usePrefersReducedMotion();
  const pendingHrefRef = useRef<string | null>(null);
  const holdTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  // 타이머와 [계속] 탭이 동시에 발화해도, StrictMode가 이펙트를 두 번 돌려도 라우팅은 한 번뿐이다.
  const hasNavigatedRef = useRef(false);
```

- [ ] **Step 3: 언마운트 정리 이펙트 추가**

`play-page.tsx`의 `useEffect(() => { ... }, [reloadKey, router, reviewStep, reviewSlot]);` 블록(`85-139`) **바로 아래**에 삽입:

```ts
  // 화면을 떠난 뒤 타이머가 살아남아 엉뚱한 라우팅을 일으키지 않게 끊는다.
  useEffect(() => {
    return () => {
      if (holdTimerRef.current !== null) {
        clearTimeout(holdTimerRef.current);
        holdTimerRef.current = null;
      }
    };
  }, []);
```

- [ ] **Step 4: 이동·연출 시작 함수 추가**

`async function submitAnswer()` **바로 위**에 삽입:

```ts
  function goToInsight() {
    if (hasNavigatedRef.current) {
      return;
    }

    hasNavigatedRef.current = true;
    if (holdTimerRef.current !== null) {
      clearTimeout(holdTimerRef.current);
      holdTimerRef.current = null;
    }

    const href = pendingHrefRef.current;
    if (href !== null) {
      router.push(href);
    }
  }

  function startCelebration(
    result: { combo: number; correct: boolean; wasRetry: boolean },
    href: string,
  ) {
    if (!quiz) {
      return;
    }

    const next = getCelebration({
      combo: result.combo,
      correct: result.correct,
      difficulty: quiz.difficulty,
      prefersReducedMotion,
      quizId: quiz.quizId,
      wasRetry: result.wasRetry,
    });

    pendingHrefRef.current = href;
    setCelebration(next);

    // holdMs가 0이면 타이머를 걸지 않고 곧바로 넘긴다 —
    // 모션을 끈 사용자에게 0ms 타이머의 한 틱을 강요할 이유가 없고,
    // 그래야 "제출 즉시 이동"이라는 기존 계약이 그대로 유지된다.
    if (next.holdMs === 0) {
      goToInsight();
      return;
    }

    holdTimerRef.current = setTimeout(goToInsight, next.holdMs);
  }
```

- [ ] **Step 5: submitAnswer의 라우팅부 교체**

`play-page.tsx:193-209`의 복습 분기와 일반 분기를 아래로 **교체**한다(그 위의 재도전 분기 `186-191`은 손대지 않는다 — 재도전 화면엔 연출이 없다):

```ts
      if (review) {
        // 복습: 오늘의 학습 스트릭·보리 포만감은 건드리지 않고, 복습 상태만 URL로 이어받는다.
        const correctAfter = review.correct + (result.isCorrect ? 1 : 0);
        const streakAfter = result.isCorrect ? review.streak + 1 : 0;
        startCelebration(
          { combo: streakAfter, correct: result.isCorrect, wasRetry: hasUsedRetry },
          reviewInsightHref(review, quiz.quizId, result.isCorrect, correctAfter, streakAfter),
        );
        return;
      }

      const session = recordAnswer(quiz.stepOrder, result.isCorrect);
      const isLastQuestion = currentNumber === totalCount;
      if (isLastQuestion) {
        // 결과를 쓰지 않으므로 기다리지 않는다 — await하면 요청 타임아웃(15초)만큼 축하가 막힌다.
        void feedMascot().catch(() => {});
      }

      startCelebration(
        { combo: session.combo, correct: result.isCorrect, wasRetry: hasUsedRetry },
        buildInsightHref(quiz.quizId, result.isCorrect, session, isLastQuestion),
      );
```

- [ ] **Step 6: URL 빌더 추가**

파일 하단(`canSubmitAnswer` 함수 정의 **위**)에 삽입:

```ts
/**
 * 해설 화면 URL. 마지막 문제면 완주 요약에 쓸 값을 함께 싣는다.
 *
 * localStorage 대신 URL로 넘기는 이유: 뒤로가기·bfcache에서 화면과 값이 어긋나는 문제를
 * PR #160에서 이미 겪었다. URL이면 그 화면의 상태가 주소에 고정된다.
 * 브라우저가 만든 값이라 신뢰하지 않으며, 해설 화면이 totalCount로 잘라 쓴다.
 */
function buildInsightHref(
  quizId: number,
  correct: boolean,
  session: PlaySession,
  isLastQuestion: boolean,
) {
  const params = new URLSearchParams({
    quizId: String(quizId),
    correct: correct ? "true" : "false",
    streak: String(session.combo),
  });

  if (isLastQuestion) {
    params.set("done", "1");
    params.set("c", String(session.correct));
    params.set("bc", String(session.bestCombo));
    params.set("a", String(session.answered));
  }

  return `/insight?${params.toString()}`;
}
```

`PlaySession` 타입 import를 위해 Step 1의 import 줄을 다음으로 바꾼다:

```ts
import { type PlaySession, recordAnswer, resetSession } from "@/features/play/session-progress";
```

- [ ] **Step 7: 스트릭 리셋 교체**

`play-page.tsx:112-114`의

```ts
          if (reviewStep === null && nextQuiz.slotOrder === 1) {
            resetCorrectStreak(nextQuiz.stepOrder);
          }
```

를 다음으로 바꾼다:

```ts
          if (reviewStep === null && nextQuiz.slotOrder === 1) {
            resetSession(nextQuiz.stepOrder);
          }
```

- [ ] **Step 8: 오버레이 렌더**

`return (` 직후의 `<main ...>` 여는 태그 **바로 다음 줄**에 삽입:

```tsx
        {celebration ? (
          <CelebrationOverlay celebration={celebration} onContinue={goToInsight} />
        ) : null}
```

- [ ] **Step 9: 기존 테스트 마이그레이션**

`app/src/test/play-page.test.tsx`의 `describe("PlayPage", () => {` 안 `beforeEach` (`68-77행`)에 한 줄 추가하고, 상단 import에 setup 헬퍼를 들여온다.

import 블록에 추가:

```ts
import { setPrefersReducedMotion } from "@/test/setup";
```

`beforeEach` 마지막 줄(`window.localStorage.clear();`) **아래**에 추가:

```ts
    // 이 스위트는 연출 타이밍이 아니라 채점·라우팅 계약을 검증한다.
    // 모션을 끄면 holdMs가 0이라 제출 즉시 이동해, 기존 단언을 그대로 쓸 수 있다.
    // 연출 타이밍은 아래 "정답 판정 연출" describe에서 따로 본다.
    setPrefersReducedMotion(true);
```

이 한 줄로 **기존 라우팅 단언 9개(95·114·148·163·230·296·463·484·509·557행)가 수정 없이 통과**한다. 실행해서 확인한다.

Run: `cd app && pnpm vitest run src/test/play-page.test.tsx`
Expected: 기존 테스트 전부 PASS

- [ ] **Step 10: 연출 검증 테스트 추가**

`play-page.test.tsx` 파일 맨 끝의 `});`(최상위 describe 닫기) **바로 위**에 삽입:

```ts
  describe("정답 판정 연출", () => {
    it("정답이면 오버레이를 띄우고 유지 시간이 지난 뒤 해설로 넘어간다", async () => {
      setPrefersReducedMotion(false);
      vi.useFakeTimers({ shouldAdvanceTime: true });
      vi.mocked(getNextQuiz).mockResolvedValue(oxQuiz);
      vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true, retryHint: null });

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("radio", { name: "O" }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      expect(await screen.findByTestId("celebration-overlay")).toHaveAttribute(
        "data-tier",
        "subtle",
      );
      expect(mockRouter.push).not.toHaveBeenCalled();

      await act(async () => {
        vi.advanceTimersByTime(500);
      });

      expect(mockRouter.push).toHaveBeenCalledWith("/insight?quizId=7&correct=true&streak=1");
      vi.useRealTimers();
    });

    it("[계속]을 누르면 유지 시간을 기다리지 않고 한 번만 이동한다", async () => {
      setPrefersReducedMotion(false);
      vi.useFakeTimers({ shouldAdvanceTime: true });
      vi.mocked(getNextQuiz).mockResolvedValue(oxQuiz);
      vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true, retryHint: null });

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("radio", { name: "O" }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      fireEvent.click(await screen.findByRole("button", { name: "계속" }));
      expect(mockRouter.push).toHaveBeenCalledTimes(1);

      // 타이머가 뒤늦게 발화해도 두 번째 이동은 없다.
      await act(async () => {
        vi.advanceTimersByTime(2000);
      });

      expect(mockRouter.push).toHaveBeenCalledTimes(1);
      vi.useRealTimers();
    });

    it("모션을 끈 사용자에게는 오버레이를 띄우되 즉시 이동한다", async () => {
      setPrefersReducedMotion(true);
      vi.mocked(getNextQuiz).mockResolvedValue(oxQuiz);
      vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true, retryHint: null });

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("radio", { name: "O" }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      await waitFor(() => {
        expect(mockRouter.push).toHaveBeenCalledWith("/insight?quizId=7&correct=true&streak=1");
      });
    });

    it("재도전 화면에서는 연출을 띄우지 않는다", async () => {
      setPrefersReducedMotion(false);
      vi.mocked(getNextQuiz).mockResolvedValue(multipleChoiceQuiz);
      vi.mocked(submitQuizAnswer).mockResolvedValue({
        isCorrect: false,
        retryHint: { eliminatedChoiceId: 12, blankHints: null },
      });

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("radio", { name: /뮤텍스/ }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      await screen.findByText(/틀린 선택지 하나를 지웠어요/);
      expect(screen.queryByTestId("celebration-overlay")).not.toBeInTheDocument();
      expect(mockRouter.push).not.toHaveBeenCalled();
    });

    it("마지막 문제면 완주 요약 값을 URL에 싣는다", async () => {
      setPrefersReducedMotion(true);
      vi.mocked(getNextQuiz).mockResolvedValue({ ...oxQuiz, slotOrder: 5, totalCount: 5 });
      vi.mocked(submitQuizAnswer).mockResolvedValue({ isCorrect: true, retryHint: null });
      window.localStorage.setItem(
        "thumbsup:play-session:1",
        JSON.stringify({ answered: 4, correct: 3, combo: 1, bestCombo: 2 }),
      );

      render(<PlayPage />);

      fireEvent.click(await screen.findByRole("radio", { name: "O" }));
      fireEvent.click(screen.getByRole("button", { name: "정답 확인" }));

      await waitFor(() => {
        expect(mockRouter.push).toHaveBeenCalledWith(
          "/insight?quizId=7&correct=true&streak=2&done=1&c=4&bc=2&a=5",
        );
      });
    });
  });
```

- [ ] **Step 11: 통과 확인**

Run: `cd app && pnpm vitest run src/test/play-page.test.tsx`
Expected: PASS (기존 + 신규 5)

> 만약 fake timer와 Testing Library가 충돌해 `findBy*`가 멈추면, `vi.useFakeTimers({ shouldAdvanceTime: true })`를 유지한 채 `render` **이전**에 타이머를 켰는지 확인한다. 그래도 불안정하면 해당 테스트만 실제 타이머 + `waitFor(..., { timeout: 3000 })`으로 바꾸되, 이유를 주석으로 남긴다.

- [ ] **Step 12: 커밋**

```bash
cd app && pnpm typecheck && pnpm lint && pnpm check:design && cd ..
git add app/src/features/play/components/play-page.tsx app/src/test/play-page.test.tsx
git commit -m "feat(app): 퀴즈 화면에 정답 판정 연출 연결 — 지연 이동·중복 라우팅 차단 (#211)"
```

---

## Task 6: 완주 파라미터 계약

**Files:**
- Create: `app/src/features/play/completion-params.ts`
- Test: `app/src/test/completion-params.test.ts`
- Modify: `app/src/app/insight/page.tsx`

**Interfaces:**
- Consumes: 없음
- Produces: `type CompletionSummary = { answered: number; correct: number; bestCombo: number }` · `type CompletionSearchParams = { done?: string; c?: string; bc?: string; a?: string }` · `parseCompletion(params?: CompletionSearchParams): CompletionSummary | null` · `clampCompletion(summary: CompletionSummary, totalCount: number): CompletionSummary` · `isPerfectCompletion(summary: CompletionSummary, totalCount: number): boolean` · `hasPlayedCompletionFanfare(key: string): boolean` · `markCompletionFanfarePlayed(key: string): void`

- [ ] **Step 1: 실패 테스트 작성**

`app/src/test/completion-params.test.ts`:

```ts
import { beforeEach, describe, expect, it } from "vitest";
import {
  clampCompletion,
  hasPlayedCompletionFanfare,
  isPerfectCompletion,
  markCompletionFanfarePlayed,
  parseCompletion,
} from "@/features/play/completion-params";

describe("parseCompletion", () => {
  it("done이 1이 아니면 null", () => {
    expect(parseCompletion(undefined)).toBeNull();
    expect(parseCompletion({ a: "5", bc: "3", c: "4" })).toBeNull();
    expect(parseCompletion({ a: "5", bc: "3", c: "4", done: "0" })).toBeNull();
  });

  it("done이 1이면 값을 읽는다", () => {
    expect(parseCompletion({ a: "5", bc: "3", c: "4", done: "1" })).toEqual({
      answered: 5,
      bestCombo: 3,
      correct: 4,
    });
  });

  it("숫자가 아니거나 음수면 0으로 본다", () => {
    expect(parseCompletion({ a: "x", bc: "-2", c: "", done: "1" })).toEqual({
      answered: 0,
      bestCombo: 0,
      correct: 0,
    });
  });
});

describe("clampCompletion", () => {
  it("URL을 조작해도 문제 수를 넘지 못한다", () => {
    expect(clampCompletion({ answered: 999, bestCombo: 999, correct: 999 }, 5)).toEqual({
      answered: 5,
      bestCombo: 5,
      correct: 5,
    });
  });

  it("정상 범위는 그대로 둔다", () => {
    expect(clampCompletion({ answered: 5, bestCombo: 2, correct: 3 }, 5)).toEqual({
      answered: 5,
      bestCombo: 2,
      correct: 3,
    });
  });
});

describe("isPerfectCompletion", () => {
  it("정답 수가 문제 수 이상이면 퍼펙트", () => {
    expect(isPerfectCompletion({ answered: 5, bestCombo: 5, correct: 5 }, 5)).toBe(true);
  });

  it("하나라도 틀리면 퍼펙트가 아니다", () => {
    expect(isPerfectCompletion({ answered: 5, bestCombo: 3, correct: 4 }, 5)).toBe(false);
  });

  it("문제 수가 0이면 퍼펙트로 치지 않는다", () => {
    expect(isPerfectCompletion({ answered: 0, bestCombo: 0, correct: 0 }, 0)).toBe(false);
  });
});

describe("팡파레 1회 가드", () => {
  beforeEach(() => {
    window.sessionStorage.clear();
  });

  it("표시하기 전에는 재생 이력이 없다", () => {
    expect(hasPlayedCompletionFanfare("daily:7")).toBe(false);
  });

  it("표시한 뒤 재진입하면 다시 재생하지 않는다", () => {
    markCompletionFanfarePlayed("daily:7");

    expect(hasPlayedCompletionFanfare("daily:7")).toBe(true);
    expect(hasPlayedCompletionFanfare("daily:8")).toBe(false);
  });
});
```

- [ ] **Step 2: 실패 확인**

Run: `cd app && pnpm vitest run src/test/completion-params.test.ts`
Expected: FAIL — 모듈 없음

- [ ] **Step 3: 최소 구현**

`app/src/features/play/completion-params.ts`:

```ts
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
export function clampCompletion(
  summary: CompletionSummary,
  totalCount: number,
): CompletionSummary {
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
```

- [ ] **Step 4: 통과 확인**

Run: `cd app && pnpm vitest run src/test/completion-params.test.ts`
Expected: PASS (10 tests)

- [ ] **Step 5: 라우트에서 파싱해 내려주기**

`app/src/app/insight/page.tsx`를 아래로 **전체 교체**:

```tsx
import { RequireAuth } from "@/features/auth/require-auth";
import { parseReviewContext, type ReviewSearchParams } from "@/features/history/review-params";
import {
  type CompletionSearchParams,
  parseCompletion,
} from "@/features/play/completion-params";
import { InsightPage } from "@/features/play/components/insight-page";

export const dynamic = "force-dynamic";

type InsightRouteProps = {
  searchParams?: Promise<
    {
      correct?: string;
      quizId?: string;
      streak?: string;
    } & ReviewSearchParams &
      CompletionSearchParams
  >;
};

export default async function Insight({ searchParams }: InsightRouteProps) {
  const params = await searchParams;
  // 소수 quizId가 다른 퀴즈로 절삭되지 않도록 양의 정수만 허용(follow-up 라우트와 동일 규약).
  const rawQuizId = Number(params?.quizId);
  const quizId = Number.isInteger(rawQuizId) && rawQuizId > 0 ? rawQuizId : null;
  const rawStreak = Number(params?.streak ?? 0);
  const correctStreak = Number.isFinite(rawStreak) ? Math.max(0, Math.trunc(rawStreak)) : 0;
  const review = parseReviewContext(params);
  // 상한 검증(clamp)은 totalCount를 아는 클라이언트에서 한다.
  const completion = parseCompletion(params);

  return (
    <RequireAuth>
      <InsightPage
        completion={completion}
        correct={params?.correct === "true"}
        correctStreak={correctStreak}
        quizId={quizId}
        review={review}
      />
    </RequireAuth>
  );
}
```

> `InsightPage`에 `completion` prop이 아직 없어 이 시점엔 타입 에러가 난다. Task 7 Step 1에서 prop을 추가하면 해소된다. **이 스텝에서는 커밋하지 않는다.**

---

## Task 7: 완주 요약 카드

**Files:**
- Create: `app/src/features/play/components/completion-card.tsx`
- Modify: `app/src/features/play/components/insight-page.tsx`
- Modify: `app/src/test/insight-page.test.tsx`

**Interfaces:**
- Consumes: `CompletionSummary`·`clampCompletion` (Task 6) · `CircleCheckIcon`·`DogIcon` from `@/components/icons`
- Produces: `<CompletionCard summary={CompletionSummary} totalCount={number} />` · `InsightPage`의 `completion?: CompletionSummary | null` prop

- [ ] **Step 1: 카드 컴포넌트 작성**

`app/src/features/play/components/completion-card.tsx`:

```tsx
import { CircleCheckIcon, DogIcon } from "@/components/icons";
import { type CompletionSummary, clampCompletion } from "@/features/play/completion-params";

type CompletionCardProps = {
  summary: CompletionSummary;
  totalCount: number;
};

export function CompletionCard({ summary, totalCount }: CompletionCardProps) {
  const safe = clampCompletion(summary, totalCount);
  // 구키에서 마이그레이션된 세션은 answered를 복원할 수 없어 0이다.
  // 틀린 숫자를 보여주느니 줄을 감춘다(session-progress.ts migrateLegacy 주석 참고).
  const canShowScore = safe.answered === totalCount && totalCount > 0;

  return (
    <div className="mt-4 rounded-control border border-border bg-surface px-4 py-4">
      <div className="flex items-center gap-2">
        <span className="grid h-8 w-8 place-items-center rounded-chip bg-success/10 text-success">
          <CircleCheckIcon className="h-5 w-5" />
        </span>
        <p className="text-sm font-bold text-ink">오늘의 학습 완료</p>
      </div>

      <dl className="mt-3 space-y-2">
        {canShowScore ? (
          <div className="flex items-center justify-between text-sm">
            <dt className="font-semibold text-ink-muted">정답</dt>
            <dd className="font-black text-ink">
              <span className="text-success">{safe.correct}</span> / {totalCount}
            </dd>
          </div>
        ) : null}
        <div className="flex items-center justify-between text-sm">
          <dt className="font-semibold text-ink-muted">최고 콤보</dt>
          <dd className="font-black text-ink">{safe.bestCombo}</dd>
        </div>
        <div className="flex items-center justify-between text-sm">
          <dt className="font-semibold text-ink-muted">보리</dt>
          {/*
            포만감 수치를 쓰지 않는다 — Mascot.MAX_FULLNESS(100) 캡 때문에
            먹이 1회가 항상 +20%인 게 아니다. 사실인 문장만 쓴다.
          */}
          <dd className="flex items-center gap-1.5 font-black text-ink">
            <DogIcon className="h-5 w-5" mood="happy" />
            밥을 줬어요
          </dd>
        </div>
      </dl>
    </div>
  );
}
```

- [ ] **Step 2: insight-page에 prop과 렌더 추가**

`insight-page.tsx`의 `InsightPageProps`(`35-41행`)에 필드 추가:

```ts
type InsightPageProps = {
  /** 값이 있으면 이 문제로 스텝 한 판이 끝났다는 뜻 — 완주 요약 카드를 그린다. */
  completion?: CompletionSummary | null;
  correct: boolean;
  correctStreak?: number;
  quizId: number | null;
  /** 값이 있으면 완료 스텝 재풀이(복습) 모드 — 꼬리질문 대신 다음 슬롯/완료로 진행한다. */
  review?: ReviewContext | null;
};
```

시그니처(`43행`)를 바꾼다:

```ts
export function InsightPage({
  completion = null,
  correct,
  correctStreak = 0,
  quizId,
  review,
}: InsightPageProps) {
```

import에 추가:

```ts
import { CompletionCard } from "@/features/play/components/completion-card";
import type { CompletionSummary } from "@/features/play/completion-params";
```

렌더에서, "적용 예시" 블록(`287-296행`)과 `<div className="mt-auto flex flex-col gap-2.5 pt-5">`(`298행`) **사이**에 삽입:

```tsx
              {completion ? (
                <CompletionCard summary={completion} totalCount={explanation.totalCount} />
              ) : null}
```

- [ ] **Step 3: 테스트 추가**

`app/src/test/insight-page.test.tsx` 최상위 `describe` 끝(마지막 `it` 뒤, 닫는 `});` 앞)에 삽입:

```ts
  it("완주 요약을 받으면 정답 수·최고 콤보·보리 줄을 그린다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(
      <InsightPage
        completion={{ answered: 5, bestCombo: 3, correct: 4 }}
        correct
        quizId={1}
      />,
    );

    expect(await screen.findByText("오늘의 학습 완료")).toBeInTheDocument();
    expect(screen.getByText("정답")).toBeInTheDocument();
    expect(screen.getByText("최고 콤보")).toBeInTheDocument();
    expect(screen.getByText("밥을 줬어요")).toBeInTheDocument();
  });

  it("조작된 완주 URL 값은 문제 수 상한으로 자른다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(
      <InsightPage
        completion={{ answered: 999, bestCombo: 999, correct: 999 }}
        correct
        quizId={1}
      />,
    );

    await screen.findByText("오늘의 학습 완료");
    expect(screen.queryByText("999")).not.toBeInTheDocument();
  });

  it("마이그레이션된 세션(answered 불일치)은 정답 줄을 감춘다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(
      <InsightPage
        completion={{ answered: 0, bestCombo: 2, correct: 0 }}
        correct
        quizId={1}
      />,
    );

    await screen.findByText("오늘의 학습 완료");
    expect(screen.queryByText("정답")).not.toBeInTheDocument();
    expect(screen.getByText("최고 콤보")).toBeInTheDocument();
  });

  it("완주가 아니면 카드를 그리지 않는다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(<InsightPage correct quizId={1} />);

    await screen.findByText(/정답이에요/);
    expect(screen.queryByText("오늘의 학습 완료")).not.toBeInTheDocument();
  });
```

> `explanation` 픽스처는 `insight-page.test.tsx:66-112`에 이미 정의돼 있고 `totalCount: 5`·`quizId: 7`이다(확인함). 새 import는 필요 없다.

- [ ] **Step 4: 통과 확인**

Run: `cd app && pnpm vitest run src/test/insight-page.test.tsx src/test/completion-params.test.ts`
Expected: 신규 4개 PASS. **기존 팡파레 테스트 5개는 아직 그대로 통과**해야 한다(팡파레 조건은 Task 8에서 바꾼다).

- [ ] **Step 5: 커밋**

```bash
cd app && pnpm typecheck && pnpm lint && pnpm check:design && cd ..
git add app/src/features/play/completion-params.ts app/src/test/completion-params.test.ts app/src/app/insight/page.tsx app/src/features/play/components/completion-card.tsx app/src/features/play/components/insight-page.tsx app/src/test/insight-page.test.tsx
git commit -m "feat(app): 완주 요약 카드 — 정답·최고 콤보·보리 (#211)"
```

---

## Task 8: 팡파레 조건 이동

기존 팡파레는 "연속 3정답"에 걸려 있어, S3 연출과 겹쳐 3콤보에서 컨페티가 두 번 터진다. 발동 조건을 **완주 퍼펙트**로 옮겨 사다리 전체가 한 번씩만 터지게 한다.

**Files:**
- Create: `app/src/features/play/components/fanfare-overlay.tsx`
- Modify: `app/src/features/play/components/insight-page.tsx`
- Modify: `app/src/features/history/components/review-summary-page.tsx`
- Modify: `app/src/test/insight-page.test.tsx`

**Interfaces:**
- Consumes: `hasPlayedCompletionFanfare`·`markCompletionFanfarePlayed`·`isPerfectCompletion` (Task 6)
- Produces: `<FanfareOverlay playKey={string} />`

- [ ] **Step 1: 팡파레 오버레이 추출**

`app/src/features/play/components/fanfare-overlay.tsx`:

```tsx
"use client";

import { type DotLottie, DotLottieReact } from "@lottiefiles/dotlottie-react";
import { useEffect, useState } from "react";
import {
  hasPlayedCompletionFanfare,
  markCompletionFanfarePlayed,
} from "@/features/play/completion-params";

const FANFARE_SRC = "/lottie/fanfare.lottie";
const FANFARE_VERTICAL_SRC = "/lottie/fanfare-vertical.lottie";

/** 사다리 꼭대기는 두 애니메이션을 겹쳐 가장 크게 터뜨린다. */
const FANFARE_SOURCES = [FANFARE_SRC, FANFARE_VERTICAL_SRC] as const;
const COMPLETE_SOURCE = FANFARE_VERTICAL_SRC;

type FanfareOverlayProps = {
  /** 같은 판에서 두 번 터지지 않게 하는 식별자. 예: `daily:123`, `review:4`. */
  playKey: string;
};

export function FanfareOverlay({ playKey }: FanfareOverlayProps) {
  const [player, setPlayer] = useState<DotLottie | null>(null);
  const [isDismissed, setIsDismissed] = useState(false);
  // 뒤로가기·새로고침으로 다시 들어와도 축하를 반복하지 않는다.
  // 첫 렌더에서 sessionStorage를 읽으면 SSR과 어긋나므로 마운트 후에 판정한다.
  const [hasChecked, setHasChecked] = useState(false);
  const [shouldPlay, setShouldPlay] = useState(false);

  useEffect(() => {
    const alreadyPlayed = hasPlayedCompletionFanfare(playKey);
    if (!alreadyPlayed) {
      markCompletionFanfarePlayed(playKey);
    }

    setShouldPlay(!alreadyPlayed);
    setHasChecked(true);
  }, [playKey]);

  useEffect(() => {
    if (!player) {
      return undefined;
    }

    function dismiss() {
      setIsDismissed(true);
    }

    player.addEventListener("complete", dismiss);

    return () => {
      player.removeEventListener("complete", dismiss);
    };
  }, [player]);

  if (!hasChecked || !shouldPlay || isDismissed) {
    return null;
  }

  return (
    <div
      aria-hidden="true"
      className="pointer-events-none fixed inset-0 z-50"
      data-sources={FANFARE_SOURCES.join(",")}
      data-testid="lottie-fanfare"
    >
      {FANFARE_SOURCES.map((source) => (
        <DotLottieReact
          autoplay
          className="absolute inset-0 h-screen w-screen"
          dotLottieRefCallback={source === COMPLETE_SOURCE ? setPlayer : undefined}
          key={source}
          loop={false}
          src={source}
        />
      ))}
    </div>
  );
}
```

- [ ] **Step 2: insight-page에서 옛 팡파레 제거하고 교체**

`insight-page.tsx`에서 다음을 **삭제**한다:
- `import { type DotLottie, DotLottieReact } from "@lottiefiles/dotlottie-react";` (3행)
- `const FANFARE_SRC = ...` · `const FANFARE_VERTICAL_SRC = ...` (32-33행)
- `const [fanfarePlayer, setFanfarePlayer] = useState<DotLottie | null>(null);` · `const [dismissedFanfareKey, setDismissedFanfareKey] = useState<string | null>(null);` (49-50행)
- `rewardStreak`·`fanfareKey`·`fanfareSources`·`fanfareCompleteSource`·`showFanfare` 계산 블록 (52-67행)
- `fanfarePlayer` 이펙트 (131-145행)
- `showFanfare ? (...)` JSX 블록 (149-167행)
- 파일 하단 `getFanfareSources` 함수 (402-416행)

`useState` import에서 더 이상 안 쓰는 것이 있으면 정리한다(`useState`는 다른 곳에서 계속 쓰므로 남는다).

**추가**할 것 — import:

```ts
import { FanfareOverlay } from "@/features/play/components/fanfare-overlay";
import {
  clampCompletion,
  type CompletionSummary,
  isPerfectCompletion,
} from "@/features/play/completion-params";
```

컴포넌트 본문 상단(`isLastQuestion` 계산 근처)에 추가:

```ts
  // 팡파레는 이제 "연속 3정답"이 아니라 완주 퍼펙트에만 터진다(#211).
  // 3콤보는 퀴즈 화면에서 이미 컨페티로 축하했으므로 여기서 또 터뜨리면 중복이다.
  const isPerfectRun =
    completion !== null &&
    explanation !== null &&
    isPerfectCompletion(clampCompletion(completion, explanation.totalCount), explanation.totalCount);
```

`<main ...>` 여는 태그 **바로 다음 줄**에 추가:

```tsx
      {isPerfectRun && quizId !== null ? <FanfareOverlay playKey={`daily:${quizId}`} /> : null}
```

- [ ] **Step 3: 복습 완료 화면에 퍼펙트 팡파레 추가**

`review-summary-page.tsx`의 import에 추가:

```ts
import { FanfareOverlay } from "@/features/play/components/fanfare-overlay";
```

`<main ...>` 여는 태그 **바로 다음 줄**에 추가:

```tsx
      {isPerfect ? <FanfareOverlay playKey={`review:${step}`} /> : null}
```

> `ReviewSummaryPage`는 서버 컴포넌트지만 `FanfareOverlay`가 `"use client"`라 그대로 중첩할 수 있다. 파일에 `"use client"`를 붙이지 **않는다**.

- [ ] **Step 4: 기존 팡파레 테스트 5묶음 재작성**

`app/src/test/insight-page.test.tsx`에서 아래 5개 `it`을 **삭제**한다(현행 220·244·260·294·319행):
- `"shows fanfare from the third consecutive correct answer and hides it on completion"`
- `"uses vertical fanfare only for the fourth consecutive correct answer"`
- `"overlays both fanfares from the fifth consecutive correct answer and dismisses on vertical completion"`
- `"shows fanfare in review mode when the review streak reaches three and keeps review completion CTA"`
- `"does not show fanfare in review mode below the review streak threshold"`

`"does not show fanfare while the explanation API is in an error state"`(현행 344행)는 **남긴다** — 단, `correctStreak={5}` 같은 스트릭 prop을 쓰고 있으면 `completion={{ answered: 5, bestCombo: 5, correct: 5 }}`로 바꾼다.

`beforeEach`에 `window.sessionStorage.clear();`를 추가한다(팡파레 1회 가드가 테스트 간에 새지 않도록).

삭제한 자리에 삽입:

```ts
  it("완주 퍼펙트면 팡파레를 두 겹으로 띄우고 재생이 끝나면 감춘다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(
      <InsightPage
        completion={{ answered: 5, bestCombo: 5, correct: 5 }}
        correct
        quizId={1}
      />,
    );

    expect(await screen.findByTestId("lottie-fanfare")).toHaveAttribute(
      "data-sources",
      "/lottie/fanfare.lottie,/lottie/fanfare-vertical.lottie",
    );

    await waitFor(() => {
      expect(getLottieListeners("/lottie/fanfare-vertical.lottie").size).toBeGreaterThan(0);
    });

    act(() => {
      for (const listener of getLottieListeners("/lottie/fanfare-vertical.lottie")) {
        listener();
      }
    });

    await waitFor(() => {
      expect(screen.queryByTestId("lottie-fanfare")).not.toBeInTheDocument();
    });
  });

  it("하나라도 틀린 완주에는 팡파레가 없다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(
      <InsightPage
        completion={{ answered: 5, bestCombo: 3, correct: 4 }}
        correct
        quizId={1}
      />,
    );

    await screen.findByText("오늘의 학습 완료");
    expect(screen.queryByTestId("lottie-fanfare")).not.toBeInTheDocument();
  });

  it("연속 정답만으로는 더 이상 팡파레가 뜨지 않는다 — 퀴즈 화면에서 이미 축하했다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);

    render(<InsightPage correct correctStreak={5} quizId={1} />);

    await screen.findByText(/정답이에요/);
    expect(screen.queryByTestId("lottie-fanfare")).not.toBeInTheDocument();
  });

  it("같은 완주 화면에 다시 들어오면 팡파레를 반복하지 않는다", async () => {
    vi.mocked(getQuizExplanation).mockResolvedValue(explanation);
    const summary = { answered: 5, bestCombo: 5, correct: 5 };

    const first = render(<InsightPage completion={summary} correct quizId={1} />);
    await screen.findByTestId("lottie-fanfare");
    first.unmount();

    render(<InsightPage completion={summary} correct quizId={1} />);

    await screen.findByText("오늘의 학습 완료");
    expect(screen.queryByTestId("lottie-fanfare")).not.toBeInTheDocument();
  });
```

- [ ] **Step 5: 통과 확인**

Run: `cd app && pnpm test`
Expected: 전체 스위트 PASS

- [ ] **Step 6: 커밋**

```bash
cd app && pnpm typecheck && pnpm lint && pnpm check:design && cd ..
git add app/src/features/play/components/fanfare-overlay.tsx app/src/features/play/components/insight-page.tsx app/src/features/history/components/review-summary-page.tsx app/src/test/insight-page.test.tsx
git commit -m "refactor(app): 팡파레 발동을 연속 3정답에서 완주 퍼펙트로 이동 (#211)"
```

---

## Task 9: 최종 게이트

- [ ] **Step 1: 전체 게이트 실행**

```bash
cd app && pnpm typecheck && pnpm lint && pnpm test && pnpm build && pnpm check:design
```

Expected: 5개 전부 통과. `build`는 Turbopack으로 도는데, 이 워크트리는 격리 설치라 심링크 문제가 없어야 한다. 실패하면 로그를 그대로 보고한다.

- [ ] **Step 2: 실제 화면 확인 (가능한 범위)**

```bash
cd app && pnpm dev
```

`http://localhost:3000/play`에서 로그인 후 문제를 풀어 오버레이가 뜨는지 확인한다. **로그인 자격이 없거나 백엔드에 접속할 수 없으면 이 스텝은 건너뛰고, 건너뛰었다고 보고에 명시한다** — 통과했다고 지어내지 말 것.

Storybook으로 연출만 보는 건 자격 없이도 된다:

```bash
cd app && pnpm storybook
```

`play/CelebrationOverlay` 스토리 7개를 눌러보고, 유지 시간이 과하거나 부족하면 `celebration-logic.ts`의 `HOLD_MS`를 조정한 뒤 `celebration-logic.test.ts`의 "등급이 올라갈수록 유지 시간이 길어진다"가 여전히 통과하는지 확인하고 커밋한다.

- [ ] **Step 3: 최종 보고**

`worker_done`에 다음을 담는다:
- 태스크별 완료 여부와 커밋 해시
- 게이트 5종의 실제 결과 (통과/실패, 실패면 로그)
- **건너뛴 검증 항목과 그 이유** (특히 Step 2)
- 계획과 다르게 구현한 부분과 그 이유
- 남은 위험·후속 이슈 제안

---

## 자체 리뷰 결과

**스펙 커버리지** — 스펙 §3 사다리→Task 2·4, §4 판정 흐름→Task 5, §5(a)→Task 1, §5(b)→Task 2, §5(c)→Task 4, §6 완주 카드→Task 6·7, §3 복습 규칙→Task 8, §7 기술→Task 4, §9 에러→Task 1·4·6 각 구현, §10 접근성→Task 3·4, §11 테스트→각 태스크. **누락 없음.**

**플레이스홀더** — 없음. Task 7 Step 3의 `explanation` 픽스처와 Task 9 Step 2의 로그인 자격은 "파일에 있는 이름에 맞춘다"·"안 되면 건너뛰고 보고"로 처리 방법까지 지정했다.

**타입 일관성** — `PlaySession`(Task 1)이 Task 5에서 `buildInsightHref` 인자로, `Celebration`(Task 2)이 Task 4·5에서, `CompletionSummary`(Task 6)가 Task 7·8에서 같은 이름·형태로 쓰인다. `getCelebration` 인자 6개가 Task 2 정의와 Task 4 스토리·Task 5 호출부에서 일치한다.

**알려진 순서 의존** — Task 6 Step 5는 타입 에러를 남긴 채 끝나고 Task 7 Step 2에서 해소된다. 그래서 Task 6은 단독 커밋하지 않고 Task 7 Step 5에서 함께 커밋한다.
