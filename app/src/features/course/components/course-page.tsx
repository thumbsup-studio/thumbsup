"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { AppTabBar } from "@/components/app-tab-bar";
import { ChevronRightIcon, LockIcon } from "@/components/icons";
import { Button } from "@/components/ui/button";
import { Chip } from "@/components/ui/chip";
import { EmptyState } from "@/components/ui/empty-state";
import { Feedback } from "@/components/ui/feedback";
import { Skeleton } from "@/components/ui/skeleton";
import { reviewStartHref } from "@/features/history/review-params";
import { buildBriefingHref } from "@/features/play/course-params";
import { isUnauthorized } from "@/features/play/quiz-shared";
import { type CourseItem, type CourseStep, getCourses } from "@/lib/api/course";

/**
 * 코스 탭 화면(이슈 220) — 코스 목록 API가 계산한 스텝 상태(완료/풀기/잠김)를 그대로
 * 활성/비활성 표시에 매핑만 한다. 구독·선택 액션은 없다 — 유저의 전체 코스가 항상 노출된다.
 */
export function CoursePage({ initialOpenCourseId }: { initialOpenCourseId?: number } = {}) {
  const router = useRouter();
  const [courses, setCourses] = useState<CourseItem[] | null>(null);
  const [openCourseId, setOpenCourseId] = useState<number | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);

  useEffect(() => {
    let ignore = false;
    const requestKey = reloadKey;

    if (requestKey < 0) {
      return undefined;
    }

    async function load() {
      setIsLoading(true);
      setError(null);

      try {
        const response = await getCourses();
        if (!ignore) {
          setCourses(response.items);
          setOpenCourseId(resolveOpenCourseId(response.items, initialOpenCourseId));
        }
      } catch (loadError) {
        if (isUnauthorized(loadError)) {
          router.replace("/login");
          return;
        }

        if (!ignore) {
          setError("코스 목록을 불러오지 못했어요.");
        }
      } finally {
        if (!ignore) {
          setIsLoading(false);
        }
      }
    }

    void load();

    return () => {
      ignore = true;
    };
  }, [reloadKey, router, initialOpenCourseId]);

  const liveText = isLoading
    ? "코스 목록을 불러오는 중"
    : error
      ? error
      : courses
        ? courses.length === 0
          ? "표시할 코스가 없어요"
          : `코스 ${courses.length}개`
        : "";

  return (
    <main className="flex min-h-dvh flex-col bg-bg px-4 py-6 text-ink sm:px-6">
      <div className="mx-auto flex w-full max-w-md flex-1 flex-col gap-5">
        <div>
          <p className="text-xs font-semibold tracking-wide text-ink-muted">코스</p>
          <h2 className="mt-1 break-keep text-2xl font-semibold tracking-tight text-ink">
            원하는 코스를 선택해
            <br />
            학습을 시작해보세요.
          </h2>
        </div>

        <p aria-live="polite" className="sr-only">
          {liveText}
        </p>

        {isLoading ? <CourseSkeleton /> : null}

        {!isLoading && error ? (
          <Feedback onRetry={() => setReloadKey((key) => key + 1)} tone="error">
            {error}
          </Feedback>
        ) : null}

        {!isLoading && !error && courses ? (
          courses.length > 0 ? (
            <ul className="flex flex-col gap-4">
              {courses.map((course) => (
                <li key={course.courseId}>
                  <CourseCard
                    course={course}
                    isOpen={openCourseId === course.courseId}
                    onToggle={() =>
                      setOpenCourseId((current) =>
                        current === course.courseId ? null : course.courseId,
                      )
                    }
                  />
                </li>
              ))}
            </ul>
          ) : (
            <EmptyState
              action={<Button onClick={() => router.push("/")}>홈으로 가기</Button>}
              description="코스가 준비되면 여기에 표시돼요."
              title="등록된 코스가 없어요"
            />
          )
        ) : null}

        <div className="sticky bottom-4 mt-auto pt-1">
          <AppTabBar activeTab="course" />
        </div>
      </div>
    </main>
  );
}

function CourseCard({
  course,
  isOpen,
  onToggle,
}: {
  course: CourseItem;
  isOpen: boolean;
  onToggle: () => void;
}) {
  return (
    <div className="overflow-hidden rounded-card border border-border bg-surface shadow-card">
      <button
        aria-expanded={isOpen}
        className="flex w-full items-center justify-between gap-3 p-5 text-left"
        onClick={onToggle}
        type="button"
      >
        <span className="min-w-0">
          <span className="block truncate text-xs font-semibold text-ink-muted">
            {course.category}
          </span>
          <span className="mt-0.5 block truncate text-lg font-bold text-ink">{course.title}</span>
        </span>
        <span className="flex shrink-0 items-center gap-2">
          {isCourseCompleted(course) ? (
            <span className="rounded-chip bg-badge px-2 py-1 text-xs font-bold text-badge-fg">
              완주
            </span>
          ) : null}
          <Chip>스텝 {course.steps.length}개</Chip>
          <ChevronRightIcon
            aria-hidden="true"
            className={`size-5 shrink-0 text-ink-muted transition-transform motion-safe:duration-200 ${
              isOpen ? "rotate-90" : ""
            }`}
          />
        </span>
      </button>
      {isOpen ? (
        <ul className="divide-y divide-border border-t border-border">
          {course.steps.map((step, index) => (
            <li key={step.stepOrder}>
              <CourseStepRow courseId={course.courseId} displayOrder={index + 1} step={step} />
            </li>
          ))}
        </ul>
      ) : null}
    </div>
  );
}

/** 목록에서 '풀 수 있는(SOLVABLE) 스텝'이 있는 첫 코스 — 기본으로 펼쳐서 보여준다. */
function findDefaultOpenCourseId(courses: CourseItem[]): number | undefined {
  return courses.find((course) => course.steps.some((step) => step.state === "SOLVABLE"))?.courseId;
}

/** 홈의 완주 카드 "복습하기"로 지정 코스가 넘어오면 그 코스를 펼친다 — 목록에 없으면(위조·삭제된 코스) 기본 규칙으로. */
function resolveOpenCourseId(
  courses: CourseItem[],
  requestedCourseId: number | undefined,
): number | null {
  if (
    requestedCourseId !== undefined &&
    courses.some((course) => course.courseId === requestedCourseId)
  ) {
    return requestedCourseId;
  }
  return findDefaultOpenCourseId(courses) ?? null;
}

function isCourseCompleted(course: CourseItem): boolean {
  return course.steps.length > 0 && course.steps.every((step) => step.state === "COMPLETED");
}

function CourseStepRow({
  courseId,
  displayOrder,
  step,
}: {
  courseId: number;
  displayOrder: number;
  step: CourseStep;
}) {
  const isLocked = step.state === "LOCKED";
  const href = getStepHref(courseId, step);

  const badge = (
    <span
      className={`grid h-11 w-11 shrink-0 place-items-center rounded-chip text-sm font-bold ${
        isLocked ? "bg-surface-muted text-ink-muted" : "bg-primary text-primary-fg"
      }`}
    >
      {isLocked ? <LockIcon aria-hidden="true" className="size-4" /> : displayOrder}
    </span>
  );

  const body = (
    <span className="min-w-0 flex-1">
      <span className="block text-xs font-semibold text-ink-muted">
        STEP {displayOrder} · {step.estimatedMinutes}분
      </span>
      <span
        className={`mt-0.5 block truncate text-base font-semibold ${
          isLocked ? "text-ink-muted" : "text-ink"
        }`}
      >
        {step.topic}
      </span>
    </span>
  );

  if (!href) {
    return (
      <div aria-disabled="true" className="flex min-h-11 items-center gap-4 p-5 opacity-60">
        {badge}
        {body}
        <StateChip state={step.state} />
      </div>
    );
  }

  return (
    <Link className="flex min-h-11 items-center gap-4 p-5" href={href}>
      {badge}
      {body}
      <StateChip state={step.state} />
      <ChevronRightIcon aria-hidden="true" className="size-5 shrink-0 text-ink-muted" />
    </Link>
  );
}

/** 스텝 클릭 시 이동 경로 — 풀 수 있으면 그 코스의 다음 문제로, 완료했으면 복습으로, 잠겼으면 없음(비활성). */
function getStepHref(courseId: number, step: CourseStep): string | undefined {
  if (step.state === "SOLVABLE") {
    return buildBriefingHref(courseId);
  }

  if (step.state === "COMPLETED") {
    return reviewStartHref(step.stepOrder, step.topic);
  }

  return undefined;
}

function StateChip({ state }: { state: CourseStep["state"] }) {
  if (state === "COMPLETED") {
    return <Chip tone="success">완료</Chip>;
  }

  if (state === "SOLVABLE") {
    return <Chip tone="primary">풀기</Chip>;
  }

  return <Chip tone="neutral">잠김</Chip>;
}

function CourseSkeleton() {
  return (
    <div className="flex flex-col gap-4">
      {[0, 1].map((row) => (
        <Skeleton className="h-44 w-full rounded-card" key={row} />
      ))}
    </div>
  );
}
