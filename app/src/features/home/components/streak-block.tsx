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
      className="shrink-0 rounded-[24px] border border-slate-200 bg-white px-4 py-3 text-right shadow-[0_12px_26px_rgba(15,23,42,0.06)]"
    >
      <p className="text-xs font-medium text-slate-500">연속 학습</p>
      <p className="mt-1 text-2xl font-semibold tracking-tight text-slate-950">
        {formatStreakDays(streakDays)}
      </p>
    </section>
  );
}
