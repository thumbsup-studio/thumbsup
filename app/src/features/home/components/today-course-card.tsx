import type { HomeData } from "@/features/home/types";

type TodayCourseCardProps = {
  course: HomeData["todayCourse"];
  onStart: () => void;
};

export function TodayCourseCard({ course, onStart }: TodayCourseCardProps) {
  return (
    <section className="rounded-[32px] bg-[linear-gradient(160deg,#2f63ff_0%,#6d8cff_100%)] px-6 py-6 text-white shadow-[0_24px_48px_rgba(47,99,255,0.24)]">
      <p className="inline-flex rounded-full border border-white/20 bg-white/12 px-3 py-1 text-xs font-semibold tracking-wide">
        오늘의 학습
      </p>
      <div className="mt-5 space-y-2">
        <p className="text-sm font-medium text-white/76">{course.title}</p>
        <h2 className="text-2xl font-semibold tracking-tight">{course.subtitle}</h2>
      </div>
      <div className="mt-6 flex items-center justify-between gap-4 text-sm text-white/88">
        <span>{course.progress}/10</span>
        <span>{course.durationLabel}</span>
      </div>
      <button
        className="mt-6 flex min-h-12 w-full items-center justify-center rounded-2xl bg-white px-4 py-3 text-base font-semibold text-blue-700"
        onClick={onStart}
        type="button"
      >
        시작하기
      </button>
    </section>
  );
}
