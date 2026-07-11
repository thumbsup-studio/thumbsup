import type { CharacterMood } from "@/components/icons";

export type WelcomeVariant = "commute" | "afterWork" | "night";

const seoulHourFormatter = new Intl.DateTimeFormat("en-US", {
  hour: "numeric",
  hour12: false,
  timeZone: "Asia/Seoul",
});

function getSeoulHour(date: Date): number {
  return Number(seoulHourFormatter.format(date));
}

export function getWelcomeVariant(date: Date): WelcomeVariant {
  const hour = getSeoulHour(date);

  if (hour < 13) {
    return "commute";
  }

  if (hour < 19) {
    return "afterWork";
  }

  return "night";
}

export function shouldShowStreak(streakDays: number): boolean {
  return streakDays > 0;
}

export function formatStreakDays(streakDays: number): string {
  return `${streakDays}일`;
}

export function formatDuration(estimatedMinutes: number): string {
  return `${estimatedMinutes}분이면 끝나요`;
}

export function formatFullness(fullness: number): string {
  const clamped = Math.min(100, Math.max(0, Math.round(fullness)));
  return `포만감 ${clamped}%`;
}

/** 포만감 구간 → 표정. 10단위 경계 — 70%↑ 행복 · 30~69% 보통 · 29%↓ 배고픔. */
export function getCharacterMood(fullness: number): CharacterMood {
  if (fullness >= 70) {
    return "happy";
  }

  if (fullness >= 30) {
    return "neutral";
  }

  return "hungry";
}

export function getWelcomeCopy(date: Date) {
  const variant = getWelcomeVariant(date);

  if (variant === "commute") {
    return {
      titleTop: "출근하며 한 문제,",
      titleBottom: "오늘도 이어가요.",
    };
  }

  if (variant === "afterWork") {
    return {
      titleTop: "자기 전에 한 문제,",
      titleBottom: "오늘도 이어가요.",
    };
  }

  return {
    titleTop: "자기 전에 한 문제,",
    titleBottom: "오늘도 이어가요.",
  };
}
