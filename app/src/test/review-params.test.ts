import { describe, expect, it } from "vitest";
import {
  parseReviewContext,
  type ReviewContext,
  reviewNextPlayHref,
  reviewPreviousPlayHref,
} from "@/features/history/review-params";

function baseContext(overrides: Partial<ReviewContext> = {}): ReviewContext {
  return {
    step: 3,
    slot: 2,
    topic: "동기화",
    ...overrides,
  };
}

describe("parseReviewContext", () => {
  it("step·slot·topic을 파싱한다", () => {
    const context = parseReviewContext({ step: "3", slot: "2", topic: "동기화" });

    expect(context).toEqual({ step: 3, slot: 2, topic: "동기화" });
  });

  it("step이나 slot이 없으면 null(=일반 문제풀이)이다", () => {
    expect(parseReviewContext(undefined)).toBeNull();
    expect(parseReviewContext({ slot: "2" })).toBeNull();
  });
});

describe("reviewNextPlayHref", () => {
  it("한 슬롯 앞으로 이동한다", () => {
    const href = reviewNextPlayHref(baseContext({ slot: 2 }));

    expect(href).toContain("/play");
    expect(href).toContain("slot=3");
  });
});

describe("reviewPreviousPlayHref", () => {
  it("한 슬롯 뒤로 이동한다", () => {
    const href = reviewPreviousPlayHref(baseContext({ slot: 3 }));

    expect(href).toContain("/play");
    expect(href).toContain("slot=2");
  });
});
