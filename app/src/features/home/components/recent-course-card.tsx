import type { HomeCourse } from "@/features/home/types";
import { buildCourseListHref, buildPlayHref } from "@/features/play/course-params";

type RecentCourseCardProps = {
  course: HomeCourse;
};

/**
 * 최근 학습 코스 카드 — 캐러셀(#23)의 슬라이드 한 장. 목록 성격은 HomePage의 섹션 제목이
 * 알려주므로 카드 자체 칩은 없다. 완주한 코스는 "다음 문제"가 없어(/quizzes/next가 항상
 * 404) CTA가 코스 탭의 그 코스 아코디언으로 보내는 "복습하기"로 바뀐다.
 * h-full+flex-col은 캐러셀에서 이웃 슬라이드와 높이를 맞추고 CTA를 바닥에 고정한다.
 */
export function RecentCourseCard({ course }: RecentCourseCardProps) {
  return (
    <section className="relative flex h-full flex-col rounded-card bg-primary px-6 py-6 text-primary-fg shadow-hero">
      {/* 완주 배지 — 오른쪽 위 모서리 스티커(절대배치)라 카드 높이·레이아웃에 영향을 주지 않는다. */}
      {course.completed && (
        <p className="absolute right-4 top-4 rounded-chip bg-badge px-3 py-1 text-sm font-bold text-badge-fg">
          완주
        </p>
      )}
      {/* 완주 배지와 제목이 겹치지 않게 완주 카드만 오른쪽 여백 확보 — 긴 제목은 먼저 줄바꿈된다. */}
      <div className={course.completed ? "space-y-2 pr-16" : "space-y-2"}>
        <p className="text-sm font-medium text-primary-fg/76">{course.title}</p>
        {/* 제목은 말줄임 없이 전부 표시한다. min-h-16(2줄분)으로 짧은 제목도 기본 높이를 확보하고,
            더 긴 제목은 그대로 늘어난다 — 캐러셀 슬라이드는 flex stretch라 칸 높이는 서로 같게 유지된다. */}
        <h2 className="min-h-16 text-2xl font-semibold tracking-tight">{course.subtitle}</h2>
      </div>
      <div className="mb-6 mt-6 flex items-baseline justify-between gap-4 text-primary-fg/88">
        <span className="flex items-baseline gap-1.5">
          {/* progress는 완료 스텝 수 — +1이 지금 풀 차례인 스텝 위치다(서버가 마지막 스텝으로 클램프해 total을 넘지 않음). */}
          <span className="sr-only">
            {course.completed
              ? `총 ${course.total}개 스텝 완주`
              : `총 ${course.total}개 스텝 중 ${course.progress + 1}번째 진행중`}
          </span>
          <span aria-hidden="true" className="text-xl font-semibold leading-none">
            {course.completed ? course.total : course.progress + 1}
          </span>
          <span aria-hidden="true" className="text-sm text-primary-fg/76">
            /{course.total}
          </span>
          <span aria-hidden="true" className="ml-1 text-sm text-primary-fg/76">
            {course.completed ? "스텝 완주" : "스텝 진행중"}
          </span>
        </span>
        <span className="text-sm">{course.durationLabel}</span>
      </div>
      <a
        className="mt-auto flex min-h-12 w-full items-center justify-center rounded-control bg-surface px-4 py-3 text-base font-semibold text-primary"
        href={
          course.completed ? buildCourseListHref(course.courseId) : buildPlayHref(course.courseId)
        }
      >
        {course.completed ? "복습하기" : "시작하기"}
      </a>
    </section>
  );
}
