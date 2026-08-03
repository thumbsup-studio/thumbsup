import type { QuizAttemptHistoryItem } from "@/lib/api/quiz";

const dayKeyFormatter = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Seoul" }); // en-CA → YYYY-MM-DD
const timeFormatter = new Intl.DateTimeFormat("ko-KR", {
  hour: "numeric",
  minute: "2-digit",
  timeZone: "Asia/Seoul",
});

function dayKey(date: Date): string {
  return dayKeyFormatter.format(date);
}

/** 풀이 시각을 "오늘"·"어제"·"n월 n일"로 — 목록의 날짜 구분선 라벨. */
export function formatAttemptDayLabel(submittedAt: string, now: Date): string {
  const submitted = new Date(submittedAt);
  const submittedKey = dayKey(submitted);
  if (submittedKey === dayKey(now)) {
    return "오늘";
  }

  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);
  if (submittedKey === dayKey(yesterday)) {
    return "어제";
  }

  return submitted.toLocaleDateString("ko-KR", {
    month: "long",
    day: "numeric",
    timeZone: "Asia/Seoul",
  });
}

/** 풀이 시각을 "오후 3:42" 형식으로. */
export function formatAttemptTime(submittedAt: string): string {
  return timeFormatter.format(new Date(submittedAt));
}

export type AttemptDayGroup = {
  dayLabel: string;
  items: QuizAttemptHistoryItem[];
};

/**
 * 최신순으로 이미 정렬된 목록을 날짜 구분선 기준으로 묶는다. API가 항상 최신순으로 주므로
 * 같은 날짜는 연속해서 나타난다 — 재정렬 없이 순서대로 훑으며 묶기만 하면 된다.
 */
export function groupAttemptsByDay(items: QuizAttemptHistoryItem[], now: Date): AttemptDayGroup[] {
  const groups: AttemptDayGroup[] = [];

  for (const item of items) {
    const dayLabel = formatAttemptDayLabel(item.submittedAt, now);
    const lastGroup = groups[groups.length - 1];
    if (lastGroup && lastGroup.dayLabel === dayLabel) {
      lastGroup.items.push(item);
    } else {
      groups.push({ dayLabel, items: [item] });
    }
  }

  return groups;
}
