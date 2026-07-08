import { formatStreakDays, shouldShowStreak } from "@/features/home/home-logic";

type StreakBlockProps = {
  streakDays: number;
};

export function StreakBlock({ streakDays }: StreakBlockProps) {
  if (!shouldShowStreak(streakDays)) {
    return null;
  }

  return (
    <section
      aria-label="연속 학습"
      className="shrink-0 rounded-card border border-border bg-surface px-4 py-3 text-right shadow-card"
    >
      <p className="text-xs font-medium text-ink-muted">연속 학습</p>
      <p className="mt-1 text-2xl font-semibold tracking-tight text-ink">
        {formatStreakDays(streakDays)}
      </p>
    </section>
  );
}
