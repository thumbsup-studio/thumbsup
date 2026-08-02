import Link from "next/link";
import { CircleCheckIcon, RotateCcwIcon } from "@/components/icons";
import {
  REVIEW_STEP_TOTAL,
  reviewSingleHref,
  reviewStartHref,
} from "@/features/history/review-params";
import { FanfareOverlay } from "@/features/play/components/fanfare-overlay";

type ReviewSummaryPageProps = {
  step: number;
  /** 이번 스텝 재풀이에서 맞힌 개수 */
  correct: number;
  topic: string;
  /** true면 문제 하나만 푼 단건 복습 — 결과 분모·다시 풀기 대상이 스텝 전체와 다르다. */
  single: boolean;
  /** 단건 복습일 때 다시 풀기 대상 슬롯 */
  slot: number;
};

export function ReviewSummaryPage({ step, correct, topic, single, slot }: ReviewSummaryPageProps) {
  const total = single ? 1 : REVIEW_STEP_TOTAL;
  const isPerfect = correct >= total;
  const retryHref = single ? reviewSingleHref(step, slot, topic) : reviewStartHref(step, topic);

  return (
    <main className="flex min-h-dvh flex-col bg-bg px-4 py-6 text-ink sm:px-6">
      {/*
        단건 복습(이슈 190)은 분모가 1이라 한 문제만 맞혀도 isPerfect가 된다.
        팡파레는 "한 판을 완주하고 전부 맞혔을 때"라는 사다리 꼭대기라, 여기선 터뜨리지 않는다.
      */}
      {!single && isPerfect ? <FanfareOverlay playKey={`review:${step}`} /> : null}
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

          <div className="w-full rounded-card border border-border bg-surface p-6 shadow-card">
            <p className="text-sm font-medium text-ink-muted">이번 복습 결과</p>
            <p className="mt-2 text-3xl font-black">
              <span className="text-success">{correct}</span>
              <span className="text-ink-muted"> / {total}</span>
            </p>
            <p className="mt-2 text-sm font-medium text-ink-muted">
              {isPerfect
                ? "완벽해요! 개념을 확실히 잡았어요."
                : "다시 풀면서 헷갈린 부분을 정리했어요."}
            </p>
          </div>
        </div>

        <div className="mt-auto flex flex-col gap-2.5 pt-6">
          <Link
            className="flex min-h-12 w-full items-center justify-center rounded-control bg-primary px-5 py-3 font-bold text-primary-fg shadow-hero"
            href="/history"
          >
            복습 목록으로
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
