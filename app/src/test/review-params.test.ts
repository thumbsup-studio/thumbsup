import { describe, expect, it } from "vitest";
import {
  isReviewPreview,
  parseReviewContext,
  type ReviewContext,
  reviewNextPlayHref,
  reviewPreviousPlayHref,
  reviewSkipHref,
} from "@/features/history/review-params";

function baseContext(overrides: Partial<ReviewContext> = {}): ReviewContext {
  return {
    step: 3,
    slot: 2,
    correct: 1,
    streak: 1,
    topic: "동기화",
    resumeSlot: 2,
    ...overrides,
  };
}

describe("parseReviewContext", () => {
  it("옛 링크처럼 rsm이 없으면 slot 자체를 라이브 에지로 본다", () => {
    const context = parseReviewContext({ step: "3", slot: "2" });

    expect(context?.resumeSlot).toBe(2);
  });

  it("rsm이 있으면 그대로 라이브 에지로 쓴다", () => {
    const context = parseReviewContext({ step: "3", slot: "2", rsm: "4" });

    expect(context?.resumeSlot).toBe(4);
  });
});

describe("isReviewPreview", () => {
  it("slot이 resumeSlot보다 작으면 미리보기다", () => {
    expect(isReviewPreview(baseContext({ slot: 2, resumeSlot: 4 }))).toBe(true);
  });

  it("slot이 resumeSlot과 같으면 라이브다", () => {
    expect(isReviewPreview(baseContext({ slot: 4, resumeSlot: 4 }))).toBe(false);
  });
});

describe("reviewNextPlayHref", () => {
  it("라이브 에지에서 부르면 resumeSlot도 함께 전진한다", () => {
    const href = reviewNextPlayHref(baseContext({ slot: 2, resumeSlot: 2 }));

    expect(href).toContain("slot=3");
    expect(href).toContain("rsm=3");
  });

  it("미리보기 중에 불러도 resumeSlot을 뒤로 밀지 않는다(이미 도달한 자리 유지)", () => {
    const href = reviewNextPlayHref(baseContext({ slot: 2, resumeSlot: 4 }));

    expect(href).toContain("slot=3");
    expect(href).toContain("rsm=4");
  });
});

describe("reviewPreviousPlayHref", () => {
  it("한 슬롯 앞으로 가되 resumeSlot(라이브 에지)은 건드리지 않는다", () => {
    const href = reviewPreviousPlayHref(baseContext({ slot: 3, resumeSlot: 5 }));

    expect(href).toContain("slot=2");
    expect(href).toContain("rsm=5");
  });
});

describe("reviewSkipHref", () => {
  it("마지막 슬롯이 아니면 연속 정답만 끊고 다음 슬롯으로 간다(정답 수는 그대로)", () => {
    const href = reviewSkipHref(baseContext({ slot: 2, correct: 1, streak: 3, resumeSlot: 2 }));

    expect(href).toContain("/play");
    expect(href).toContain("slot=3");
    expect(href).toContain("rc=1");
    expect(href).toContain("rs=0");
  });

  it("마지막 슬롯이면 완료 요약으로 바로 간다", () => {
    const href = reviewSkipHref(baseContext({ slot: 5, correct: 3, streak: 2, resumeSlot: 5 }));

    expect(href).toContain("/history/done");
    expect(href).toContain("rc=3");
    expect(href).toContain("rs=0");
  });
});
