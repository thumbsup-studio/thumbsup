import type { HomeData } from "@/features/home/types";

type TodayCourseCardProps = {
  course: HomeData["todayCourse"];
  startHref: string;
};

export function TodayCourseCard({ course, startHref }: TodayCourseCardProps) {
  return (
    <section className="rounded-card bg-primary px-6 py-6 text-primary-fg shadow-hero">
      <p className="inline-flex rounded-chip border border-surface/20 bg-surface/12 px-3 py-1 text-xs font-semibold tracking-wide">
        오늘의 학습
      </p>
      <div className="mt-5 space-y-2">
        <p className="text-sm font-medium text-primary-fg/76">{course.title}</p>
        <h2 className="text-2xl font-semibold tracking-tight">{course.subtitle}</h2>
      </div>
      <div className="mt-6 flex items-center justify-between gap-4 text-sm text-primary-fg/88">
        <span>
          {course.progress}/{course.total}
        </span>
        <span>{course.durationLabel}</span>
      </div>
      <a
        className="mt-6 flex min-h-12 w-full items-center justify-center rounded-control bg-surface px-4 py-3 text-base font-semibold text-primary"
        href={startHref}
      >
        시작하기
      </a>
    </section>
  );
}
