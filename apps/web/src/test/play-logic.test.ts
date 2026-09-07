import { describe, expect, it } from "vitest";
import { mockPlaySession } from "@/features/play/mock-play-session";
import {
  canSubmitAnswer,
  clampQuestionIndex,
  getProgressPercent,
  gradeMockAnswer,
  normalizeKeywordAnswer,
} from "@/features/play/play-logic";

describe("play logic", () => {
  it("maps a 5-question session to current-position progress", () => {
    expect(getProgressPercent(0, 5)).toBe(20);
    expect(getProgressPercent(4, 5)).toBe(100);
  });

  it("clamps route question indexes to the session range", () => {
    expect(clampQuestionIndex(-10, 5)).toBe(0);
    expect(clampQuestionIndex(99, 5)).toBe(4);
    expect(clampQuestionIndex(Number.NaN, 5)).toBe(0);
  });

  it("keeps empty answers from being submitted", () => {
    const oxQuestion = mockPlaySession.questions[0];
    const blankQuestion = mockPlaySession.questions[4];

    expect(canSubmitAnswer(oxQuestion, null)).toBe(false);
    expect(canSubmitAnswer(oxQuestion, false)).toBe(true);
    expect(canSubmitAnswer(blankQuestion, "   ")).toBe(false);
  });

  it("grades ox, multiple choice, and normalized keyword answers", () => {
    expect(gradeMockAnswer(mockPlaySession.questions[0], true).correct).toBe(true);
    expect(gradeMockAnswer(mockPlaySession.questions[2], "b").correct).toBe(true);
    expect(gradeMockAnswer(mockPlaySession.questions[4], " Critical   Section ").correct).toBe(
      true,
    );
    expect(normalizeKeywordAnswer(" 임계   구역 ")).toBe("임계 구역");
  });
});
