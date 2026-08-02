import { describe, expect, it } from "vitest";
import { type CelebrationInput, getCelebration } from "@/features/play/celebration-logic";

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

  it('콤보 칩은 2부터 그린다 — 1콤보에 "1콤보"는 어색하다', () => {
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
    expect(getCelebration(input({ correct: false, prefersReducedMotion: true })).holdMs).toBe(0);
  });

  it("등급을 subtle로 눌러 컨페티가 안 터지게 한다", () => {
    expect(getCelebration(input({ combo: 5, prefersReducedMotion: true })).tier).toBe("subtle");
  });

  it("오답은 모션을 꺼도 none 그대로다", () => {
    expect(getCelebration(input({ correct: false, prefersReducedMotion: true })).tier).toBe("none");
  });

  it("문구와 배지는 모션과 무관하게 유지한다", () => {
    const result = getCelebration(
      input({ combo: 5, difficulty: "HARD", prefersReducedMotion: true }),
    );

    expect(result.badge).toBe("난이도 상 정복");
    expect(result.comboCount).toBe(5);
  });
});
