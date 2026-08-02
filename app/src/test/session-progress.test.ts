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
