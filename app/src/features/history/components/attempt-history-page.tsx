"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useRef, useState } from "react";
import { Chip } from "@/components/ui/chip";
import { EmptyState } from "@/components/ui/empty-state";
import { Feedback } from "@/components/ui/feedback";
import { Skeleton } from "@/components/ui/skeleton";
import { formatAttemptTime, groupAttemptsByDay } from "@/features/history/attempt-history-logic";
import { getPlayQuestionKindLabel, isUnauthorized } from "@/features/play/quiz-shared";
import { getAttemptHistory, type QuizAttemptHistoryItem } from "@/lib/api";

const PAGE_SIZE = 20;

export function AttemptHistoryPage() {
  const router = useRouter();
  const [items, setItems] = useState<QuizAttemptHistoryItem[]>([]);
  const [cursor, setCursor] = useState<string | null>(null);
  const [hasNext, setHasNext] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
  const sentinelRef = useRef<HTMLDivElement | null>(null);

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
        const response = await getAttemptHistory(null, PAGE_SIZE);
        if (!ignore) {
          setItems(response.data.items);
          setHasNext(response.meta?.hasNext ?? false);
          setCursor(response.meta?.nextCursor ?? null);
        }
      } catch (loadError) {
        if (isUnauthorized(loadError)) {
          router.replace("/login");
          return;
        }

        if (!ignore) {
          setError("풀이 기록을 불러오지 못했어요.");
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

  const loadMore = useCallback(async () => {
    if (!hasNext || isLoadingMore || cursor === null) {
      return;
    }

    setIsLoadingMore(true);
    try {
      const response = await getAttemptHistory(cursor, PAGE_SIZE);
      setItems((current) => [...current, ...response.data.items]);
      setHasNext(response.meta?.hasNext ?? false);
      setCursor(response.meta?.nextCursor ?? null);
    } catch (loadError) {
      if (isUnauthorized(loadError)) {
        router.replace("/login");
        return;
      }
      // 다음 페이지 실패는 목록을 지우지 않고 조용히 중단 — 사용자는 스크롤을 멈추면 그만이다.
    } finally {
      setIsLoadingMore(false);
    }
  }, [cursor, hasNext, isLoadingMore, router]);

  useEffect(() => {
    const sentinel = sentinelRef.current;
    if (!sentinel || !hasNext) {
      return undefined;
    }

    const observer = new IntersectionObserver((entries) => {
      if (entries[0]?.isIntersecting) {
        void loadMore();
      }
    });
    observer.observe(sentinel);

    return () => observer.disconnect();
  }, [hasNext, loadMore]);

  const now = new Date();
  const groups = groupAttemptsByDay(items, now);

  const liveText = isLoading
    ? "풀이 기록을 불러오는 중"
    : error
      ? error
      : items.length === 0
        ? "아직 푼 문제가 없어요"
        : `풀이 기록 ${items.length}건`;

  return (
    <main className="flex min-h-dvh flex-col bg-bg px-4 py-6 text-ink sm:px-6">
      <div className="mx-auto flex w-full max-w-md flex-1 flex-col gap-5">
        <header className="flex flex-col gap-2">
          <a
            className="grid h-10 w-10 place-items-center rounded-chip border border-border bg-surface-muted text-lg"
            aria-label="히스토리로 돌아가기"
            href="/history"
          >
            ‹
          </a>
          <div>
            <p className="text-xs font-semibold tracking-wide text-ink-muted">히스토리</p>
            <h1 className="mt-1 break-keep text-2xl font-semibold tracking-tight text-balance text-ink">
              내가 푼 문제
            </h1>
            {!isLoading && !error ? (
              <p className="mt-2 text-sm font-medium text-ink-muted">
                지금까지 {items.length}문제 풀었어요
              </p>
            ) : null}
          </div>
        </header>

        <p aria-live="polite" className="sr-only">
          {liveText}
        </p>

        {isLoading ? <AttemptHistorySkeleton /> : null}

        {!isLoading && error ? (
          <Feedback onRetry={() => setReloadKey((key) => key + 1)} tone="error">
            {error}
          </Feedback>
        ) : null}

        {!isLoading && !error && items.length === 0 ? (
          <EmptyState
            description="오늘의 학습을 시작하면 여기에서 풀이 기록을 볼 수 있어요."
            title="아직 푼 문제가 없어요"
          />
        ) : null}

        {!isLoading && !error && items.length > 0 ? (
          <div className="flex flex-col gap-3">
            {groups.map((group) => (
              <div className="flex flex-col gap-3" key={group.dayLabel + group.items[0]?.attemptId}>
                <p className="mt-2 text-xs font-bold text-ink-muted first:mt-0">{group.dayLabel}</p>
                {group.items.map((item) => (
                  <AttemptCard item={item} key={item.attemptId} />
                ))}
              </div>
            ))}

            {hasNext ? (
              <div
                className="flex items-center justify-center gap-2 py-2 text-xs font-semibold text-ink-muted"
                ref={sentinelRef}
              >
                <span
                  aria-hidden="true"
                  className="size-3.5 rounded-full border-2 border-border border-t-primary motion-safe:animate-spin"
                />
                더 불러오는 중
              </div>
            ) : null}
          </div>
        ) : null}
      </div>
    </main>
  );
}

function AttemptCard({ item }: { item: QuizAttemptHistoryItem }) {
  return (
    <article className="flex flex-col gap-2.5 rounded-card border border-border bg-surface p-4">
      <div className="flex items-start justify-between gap-3">
        <span className="flex items-center gap-2 text-xs font-bold uppercase tracking-wide text-ink-muted">
          <span>{getPlayQuestionKindLabel(item.type)}</span>
          <span aria-hidden="true" className="size-1 rounded-full bg-ink-muted/60" />
          <span>{formatAttemptTime(item.submittedAt)}</span>
        </span>
        <Chip className="shrink-0" tone={item.isCorrect ? "success" : "danger"}>
          {item.isCorrect ? "✓ 정답" : "✕ 오답"}
        </Chip>
      </div>
      <p className="line-clamp-2 text-sm font-bold leading-6 text-ink">{item.questionText}</p>
      {item.selectedAnswer !== null ? (
        <div className="flex items-start gap-2 text-sm">
          <span className="shrink-0 pt-1 font-semibold text-ink-muted">내가 고른 답</span>
          <span className="line-clamp-2 rounded-control bg-surface-muted px-3 py-1 font-bold text-ink">
            {item.selectedAnswer}
          </span>
        </div>
      ) : null}
    </article>
  );
}

function AttemptHistorySkeleton() {
  return (
    <div className="flex flex-col gap-3">
      {[0, 1, 2, 3].map((row) => (
        <Skeleton className="h-24 w-full rounded-card" key={row} />
      ))}
    </div>
  );
}
