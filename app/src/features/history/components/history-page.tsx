"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { AppTabBar } from "@/components/app-tab-bar";
import { ChevronRightIcon } from "@/components/icons";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import { Feedback } from "@/components/ui/feedback";
import { Skeleton } from "@/components/ui/skeleton";
import {
  REVIEW_STEP_TOTAL,
  reviewSingleHref,
  reviewStartHref,
} from "@/features/history/review-params";
import { isUnauthorized } from "@/features/play/quiz-shared";
import { type CompletedStep, getCompletedSteps } from "@/lib/api";

const reviewSlots = Array.from({ length: REVIEW_STEP_TOTAL }, (_, index) => index + 1);

export function HistoryPage() {
  const router = useRouter();
  const [steps, setSteps] = useState<CompletedStep[] | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [openStep, setOpenStep] = useState<number | null>(null);

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
        const response = await getCompletedSteps();
        if (!ignore) {
          setSteps(response.steps);
        }
      } catch (loadError) {
        if (isUnauthorized(loadError)) {
          router.replace("/login");
          return;
        }

        if (!ignore) {
          setError("복습할 스텝을 불러오지 못했어요.");
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
  }, [reloadKey, router]);

  // 상태 전환을 스크린리더에 알린다(play-page의 liveText 패턴과 동일).
  const liveText = isLoading
    ? "복습할 스텝을 불러오는 중"
    : error
      ? error
      : steps
        ? steps.length === 0
          ? "완료한 스텝이 없어요"
          : `복습할 스텝 ${steps.length}개`
        : "";

  return (
    <main className="flex min-h-dvh flex-col bg-bg px-4 py-6 text-ink sm:px-6">
      <div className="mx-auto flex w-full max-w-md flex-1 flex-col gap-5">
        <header className="flex items-start gap-3">
          <div className="min-w-0 flex-1">
            <p className="text-xs font-semibold tracking-wide text-ink-muted">복습</p>
            <h2 className="mt-1 break-keep text-2xl font-semibold tracking-tight text-balance text-ink">
              완료한 스텝을 다시 풀어보세요.
            </h2>
            {steps && steps.length > 0 ? (
              <p className="mt-2 text-sm font-medium text-ink-muted">
                완료한 스텝 {steps.length}개
              </p>
            ) : null}
          </div>
          <Link
            className="inline-flex min-h-11 shrink-0 items-center justify-center rounded-control bg-surface px-4 text-sm font-bold text-ink shadow-card"
            href="/history"
          >
            지식 그래프
          </Link>
        </header>

        <p aria-live="polite" className="sr-only">
          {liveText}
        </p>

        {isLoading ? <HistorySkeleton /> : null}

        {!isLoading && error ? (
          <Feedback onRetry={() => setReloadKey((key) => key + 1)} tone="error">
            {error}
          </Feedback>
        ) : null}

        {!isLoading && !error && steps ? (
          steps.length > 0 ? (
            <ul className="flex flex-col gap-3">
              {steps.map((step) => {
                const isOpen = openStep === step.stepOrder;

                return (
                  <li key={step.stepOrder}>
                    <div className="overflow-hidden rounded-card border border-border bg-surface shadow-card">
                      <button
                        aria-expanded={isOpen}
                        className="flex w-full items-center gap-4 p-5 text-left"
                        onClick={() =>
                          setOpenStep((current) =>
                            current === step.stepOrder ? null : step.stepOrder,
                          )
                        }
                        type="button"
                      >
                        <span className="grid h-11 w-11 shrink-0 place-items-center rounded-chip bg-surface-muted text-sm font-bold text-ink-muted">
                          {step.stepOrder}
                        </span>
                        <span className="min-w-0 flex-1">
                          <span className="block text-xs font-semibold text-ink-muted">
                            STEP {step.stepOrder}
                          </span>
                          <span className="mt-0.5 block truncate text-base font-semibold text-ink">
                            {step.topic}
                          </span>
                        </span>
                        <ChevronRightIcon
                          className={`size-5 shrink-0 text-ink-muted transition-transform motion-safe:duration-200 ${
                            isOpen ? "rotate-90" : ""
                          }`}
                        />
                      </button>

                      {isOpen ? (
                        <div className="border-t border-border p-4">
                          <Link
                            className="flex min-h-11 items-center justify-center rounded-control bg-primary px-4 text-sm font-bold text-primary-fg"
                            href={reviewStartHref(step.stepOrder, step.topic)}
                          >
                            전체 복습 ({REVIEW_STEP_TOTAL}문제)
                          </Link>

                          <p className="mt-3 text-xs font-semibold text-ink-muted">
                            문제 하나만 다시 풀기
                          </p>
                          <div className="mt-2 grid grid-cols-5 gap-2">
                            {reviewSlots.map((slot) => (
                              <Link
                                aria-label={`${slot}번 문제 다시 풀기`}
                                className="flex min-h-11 items-center justify-center rounded-control border border-border bg-surface-muted text-sm font-semibold text-ink"
                                href={reviewSingleHref(step.stepOrder, slot, step.topic)}
                                key={slot}
                              >
                                {slot}
                              </Link>
                            ))}
                          </div>
                        </div>
                      ) : null}
                    </div>
                  </li>
                );
              })}
            </ul>
          ) : (
            <EmptyState
              action={<Button onClick={() => router.push("/")}>학습하러 가기</Button>}
              description="오늘의 학습을 먼저 풀면 여기에서 복습할 수 있어요."
              title="아직 완료한 스텝이 없어요"
            />
          )
        ) : null}

        <div className="sticky bottom-4 mt-auto pt-1">
          <AppTabBar activeTab="history" />
        </div>
      </div>
    </main>
  );
}

function HistorySkeleton() {
  return (
    <div className="flex flex-col gap-3">
      {[0, 1, 2].map((row) => (
        <Skeleton className="h-20 w-full rounded-card" key={row} />
      ))}
    </div>
  );
}
