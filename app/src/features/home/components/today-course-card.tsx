import { CircleCheckIcon } from "@/components/icons";
import type { HomeCourse } from "@/features/home/types";
import { buildPlayHref } from "@/features/play/course-params";

type TodayCourseCardProps = {
  course: HomeCourse;
  completed: boolean;
};

/**
 * 학습 중인 코스 카드 — 캐러셀(#23)의 슬라이드 한 장. "오늘 학습 완료"(todayCompleted)는
 * 코스가 아니라 그날의 상태라 칩으로만 표시하고, 시작하기 CTA는 항상 유지한다
 * (코스 탭에서 무제한 풀이가 가능한데 홈만 막으면 비일관 — 이슈 240 논의).
 */
export function TodayCourseCard({ course, completed }: TodayCourseCardProps) {
  return (
    <section className="rounded-card bg-primary px-6 py-6 text-primary-fg shadow-hero">
      {completed ? (
        <p className="inline-flex items-center gap-1.5 rounded-chip border border-surface/20 bg-surface/12 px-3 py-1 text-xs font-semibold tracking-wide">
          <CircleCheckIcon className="size-4" aria-hidden="true" />
          오늘 학습 완료
        </p>
      ) : (
        <p className="inline-flex rounded-chip border border-surface/20 bg-surface/12 px-3 py-1 text-xs font-semibold tracking-wide">
          오늘의 학습
        </p>
      )}
      <div className="mt-5 space-y-2">
        <p className="text-sm font-medium text-primary-fg/76">{course.title}</p>
        <h2 className="text-2xl font-semibold tracking-tight">{course.subtitle}</h2>
      </div>
      <div className="mt-6 flex items-baseline justify-between gap-4 text-primary-fg/88">
        <span className="flex items-baseline gap-1.5">
          <span className="sr-only">{`총 ${course.total}개 중 ${course.progress}개 코스 진행중`}</span>
          <span aria-hidden="true" className="text-xl font-semibold leading-none">
            {course.progress}
          </span>
          <span aria-hidden="true" className="text-sm text-primary-fg/76">
            /{course.total}
          </span>
          <span aria-hidden="true" className="ml-1 text-sm text-primary-fg/76">
            코스 진행중
          </span>
        </span>
        <span className="text-sm">{course.durationLabel}</span>
      </div>
      <a
        className="mt-6 flex min-h-12 w-full items-center justify-center rounded-control bg-surface px-4 py-3 text-base font-semibold text-primary"
        href={buildPlayHref(course.courseId)}
      >
        시작하기
      </a>
    </section>
  );
}
