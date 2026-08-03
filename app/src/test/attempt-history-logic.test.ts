import { describe, expect, it } from "vitest";
import {
  formatAttemptDayLabel,
  formatAttemptTime,
  groupAttemptsByDay,
} from "@/features/history/attempt-history-logic";
import type { QuizAttemptHistoryItem } from "@/lib/api/quiz";

const NOW = new Date("2026-08-03T10:00:00+09:00");

function item(overrides: Partial<QuizAttemptHistoryItem>): QuizAttemptHistoryItem {
  return {
    attemptId: 1,
    quizId: 1,
    type: "OX",
    questionText: "문제",
    selectedAnswer: "O",
    isCorrect: true,
    submittedAt: "2026-08-03T09:00:00+09:00",
    ...overrides,
  };
}

describe("formatAttemptDayLabel", () => {
  it("같은 날이면 '오늘'을 반환한다", () => {
    expect(formatAttemptDayLabel("2026-08-03T09:00:00+09:00", NOW)).toBe("오늘");
  });

  it("하루 전이면 '어제'를 반환한다", () => {
    expect(formatAttemptDayLabel("2026-08-02T23:59:00+09:00", NOW)).toBe("어제");
  });

  it("이틀 이상 전이면 'n월 n일'로 반환한다", () => {
    expect(formatAttemptDayLabel("2026-07-30T09:00:00+09:00", NOW)).toBe("7월 30일");
  });

  it("자정 근처 KST 경계도 정확히 구분한다", () => {
    // UTC로는 8/2 15:30이지만 KST로는 8/3 00:30 — '오늘'이어야 한다
    expect(formatAttemptDayLabel("2026-08-02T15:30:00Z", NOW)).toBe("오늘");
  });
});

describe("formatAttemptTime", () => {
  it("오후 h:mm 형식으로 반환한다", () => {
    expect(formatAttemptTime("2026-08-03T15:05:00+09:00")).toBe("오후 3:05");
  });

  it("오전 h:mm 형식으로 반환한다", () => {
    expect(formatAttemptTime("2026-08-03T09:05:00+09:00")).toBe("오전 9:05");
  });
});

describe("groupAttemptsByDay", () => {
  it("같은 날짜의 연속된 항목을 하나의 그룹으로 묶는다", () => {
    const items = [
      item({ attemptId: 3, submittedAt: "2026-08-03T09:30:00+09:00" }),
      item({ attemptId: 2, submittedAt: "2026-08-03T09:00:00+09:00" }),
      item({ attemptId: 1, submittedAt: "2026-08-02T20:00:00+09:00" }),
    ];

    const groups = groupAttemptsByDay(items, NOW);

    expect(groups).toHaveLength(2);
    expect(groups[0]?.dayLabel).toBe("오늘");
    expect(groups[0]?.items).toHaveLength(2);
    expect(groups[1]?.dayLabel).toBe("어제");
    expect(groups[1]?.items).toHaveLength(1);
  });

  it("빈 목록은 빈 그룹 배열을 반환한다", () => {
    expect(groupAttemptsByDay([], NOW)).toEqual([]);
  });
});
