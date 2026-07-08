export type WelcomeVariant = "commute" | "afterWork" | "night";

export function getWelcomeVariant(date: Date): WelcomeVariant {
  const hour = date.getHours();

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

export function getWelcomeCopy(date: Date) {
  const variant = getWelcomeVariant(date);

  if (variant === "commute") {
    return {
      titleTop: "출근 전에 한 문제,",
      titleBottom: "오늘도 이어가요.",
    };
  }

  if (variant === "afterWork") {
    return {
      titleTop: "퇴근한 지금,",
      titleBottom: "오늘의 개념을 정리해요.",
    };
  }

  return {
    titleTop: "자기 전에 한 번 더,",
    titleBottom: "오늘 배운 걸 잠깐 확인해요.",
  };
}
