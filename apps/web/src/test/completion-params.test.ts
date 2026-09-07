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
