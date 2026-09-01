import Link from "next/link";
import { CircleCheckIcon, RotateCcwIcon } from "@/components/icons";
import { reviewStartHref } from "@/features/history/review-params";
import { COURSE_LIST_PATH } from "@/features/play/course-params";

type ReviewSummaryPageProps = {
  step: number;
  topic: string;
};

export function ReviewSummaryPage({ step, topic }: ReviewSummaryPageProps) {
  const retryHref = reviewStartHref(step, topic);

  return (
    <main className="flex min-h-dvh flex-col bg-bg px-4 py-6 text-ink sm:px-6">
      <div className="mx-auto flex w-full max-w-md flex-1 flex-col">
        <div className="flex flex-1 flex-col items-center justify-center gap-6 text-center">
          <div className="flex flex-col items-center gap-3">
            <span className="grid h-16 w-16 place-items-center rounded-card bg-success/10 text-success">
              <CircleCheckIcon className="size-8" />
            </span>
            <div>
              <p className="text-xs font-semibold tracking-wide text-ink-muted">
                STEP {step} 복습 완료
              </p>
              <h1 className="mt-1 break-keep text-2xl font-semibold tracking-tight text-balance">
                {topic}
              </h1>
            </div>
          </div>
        </div>

        <div className="mt-auto flex flex-col gap-2.5 pt-6">
          <Link
            className="flex min-h-12 w-full items-center justify-center rounded-control bg-primary px-5 py-3 font-bold text-primary-fg shadow-hero"
            href={COURSE_LIST_PATH}
          >
            코스로 돌아가기
          </Link>
          <Link
            className="flex min-h-12 w-full items-center justify-center gap-2 rounded-control border border-border bg-surface px-5 py-3 font-bold text-ink"
            href={retryHref}
          >
            <RotateCcwIcon className="size-5" />
            다시 풀기
          </Link>
        </div>
      </div>
    </main>
  );
}
