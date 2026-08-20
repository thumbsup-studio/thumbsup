"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import { Feedback } from "@/components/ui/feedback";
import { Skeleton } from "@/components/ui/skeleton";
import { BriefingContent } from "@/features/briefing/components/briefing-content";
import {
  buildCourseListHref,
  buildPlayHref,
  COURSE_LIST_PATH,
} from "@/features/play/course-params";
import { ApiError } from "@/lib/api";
import { getNextStepBriefing, type QuizStepBriefingResponse } from "@/lib/api/quiz";

type LoadState =
  | { status: "loading" }
  | { status: "network-error" }
  | { status: "success"; briefing: QuizStepBriefingResponse };

export function BriefingScreen({ courseId }: { courseId?: number }) {
  const router = useRouter();
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const [isDetailExpanded, setIsDetailExpanded] = useState(false);

  const load = useCallback(async () => {
    if (!courseId) return;

    setState({ status: "loading" });
    try {
      const briefing = await getNextStepBriefing(courseId);
      setState({ status: "success", briefing });
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        router.replace("/login");
        return;
      }
      if (error instanceof ApiError && error.code === "QUIZ_STEP_BRIEFING_NOT_AVAILABLE") {
        console.error("현재 스텝 브리핑 누락으로 기존 문제 흐름으로 우회합니다.", {
          courseId,
          code: error.code,
        });
        router.replace(buildPlayHref(courseId));
        return;
      }
      if (error instanceof ApiError && error.code === "QUIZ_STEP_COMPLETED") {
        router.replace(buildCourseListHref(courseId));
        return;
      }
      if (error instanceof ApiError && (error.status === 403 || error.code === "QUIZ_NOT_FOUND")) {
        router.replace(COURSE_LIST_PATH);
        return;
      }
      setState({ status: "network-error" });
    }
  }, [courseId, router]);

  useEffect(() => {
    void load();
  }, [load]);

  if (!courseId) {
    return (
      <BriefingShell>
        <EmptyState
          title="학습할 코스를 찾지 못했어요"
          description="코스에서 풀 수 있는 스텝을 다시 선택해 주세요."
          action={
            <Button onClick={() => router.replace(COURSE_LIST_PATH)} variant="secondary">
              코스 보러 가기
            </Button>
          }
        />
      </BriefingShell>
    );
  }

  if (state.status === "loading") {
    return <BriefingSkeleton />;
  }

  if (state.status === "network-error") {
    return (
      <BriefingShell>
        <Feedback onRetry={() => void load()} tone="error">
          브리핑을 불러오지 못했어요. 네트워크 연결을 확인해 주세요.
        </Feedback>
      </BriefingShell>
    );
  }

  const { briefing } = state;
  const playHref = buildPlayHref(courseId, briefing.quizStepId);

  return (
    <BriefingShell>
      <header>
        <p className="text-xs font-semibold tracking-wide text-ink-muted">
          STEP {briefing.stepOrder} · 문제 전 워밍업
        </p>
        <h1 className="mt-1 break-keep text-2xl font-bold tracking-tight text-ink">
          {briefing.topic}
        </h1>
      </header>

      <BriefingContent
        blocks={briefing.blocks}
        expanded={isDetailExpanded}
        headingLevel="h3"
        summary={briefing.summary}
        variant="overview"
      />

      <Button
        aria-controls="briefing-content"
        aria-expanded={isDetailExpanded}
        className="self-center"
        onClick={() => setIsDetailExpanded((expanded) => !expanded)}
        variant="secondary"
      >
        {isDetailExpanded ? "간단히 보기" : "자세히 읽기"}
      </Button>

      <div className="sticky bottom-4 mt-auto rounded-card border border-border bg-surface p-3 shadow-card">
        <Link
          className="flex min-h-12 w-full items-center justify-center rounded-control bg-primary px-4 py-3 text-base font-semibold text-primary-fg transition duration-150 active:scale-95"
          href={playHref}
        >
          문제 풀기
        </Link>
      </div>
    </BriefingShell>
  );
}

function BriefingShell({ children }: { children: React.ReactNode }) {
  return (
    <main className="flex min-h-dvh flex-col bg-bg px-4 py-6 text-ink sm:px-6">
      <div className="mx-auto flex w-full max-w-md flex-1 flex-col gap-5">{children}</div>
    </main>
  );
}

function BriefingSkeleton() {
  return (
    <BriefingShell>
      <div className="flex flex-col gap-2">
        <Skeleton className="h-4 w-36" />
        <Skeleton className="h-8 w-52" />
      </div>
      <Skeleton className="h-64 w-full rounded-card" />
      <Skeleton className="h-12 w-32 self-center rounded-control" />
    </BriefingShell>
  );
}
