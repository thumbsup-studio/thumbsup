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
      className="rounded-[28px] border border-slate-200 bg-white px-6 py-5 shadow-[0_18px_40px_rgba(15,23,42,0.06)]"
    >
      <p className="text-sm font-medium text-slate-500">연속 학습</p>
      <p className="mt-2 text-4xl font-semibold tracking-tight text-slate-950">
        {formatStreakDays(streakDays)}
      </p>
    </section>
  );
}
