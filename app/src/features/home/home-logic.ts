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
      eyebrow: "Today",
      title: "출근 전에 한 문제, 오늘도 이어가요.",
      body: "짧게 풀고 넘어가도 학습 흐름은 계속 이어집니다.",
    };
  }

  if (variant === "afterWork") {
    return {
      eyebrow: "Today",
      title: "퇴근한 지금, 오늘의 개념을 정리해요.",
      body: "집에 가기 전에 핵심 한 문제로 흐름을 붙잡아 둡니다.",
    };
  }

  return {
    eyebrow: "Today",
    title: "자기 전에 한 번 더, 오늘 배운 걸 잠깐 확인해요.",
    body: "부담 없는 3분 복습으로 내일의 감각을 남겨 둡니다.",
  };
}
