import { formatStreakDays, shouldShowStreak } from "@/features/home/home-logic";

type StreakBlockProps = {
  streakDays: number;
};

export function StreakBlock({ streakDays }: StreakBlockProps) {
  // 연속 기록이 없을 때(0일)는 카드를 숨기지 않고, 시작을 조용히 권하는 '시작 전' 상태로 대체한다.
  if (!shouldShowStreak(streakDays)) {
    return (
      <section
        aria-label="연속 학습"
        className="shrink-0 rounded-card border border-dashed border-border bg-surface-muted px-4 py-3 text-center"
      >
        <p className="text-xs font-medium text-ink-muted">연속 학습</p>
        <p className="mt-1 text-base font-semibold text-ink-muted">오늘 시작</p>
      </section>
    );
  }

  return (
    <section
      aria-label="연속 학습"
      className="shrink-0 rounded-card border border-border bg-surface px-4 py-3 text-center shadow-card"
    >
      <p className="text-xs font-medium text-ink-muted">연속 학습</p>
      <p className="mt-1 text-2xl font-semibold tracking-tight text-ink">
        {formatStreakDays(streakDays)}
      </p>
    </section>
  );
}
