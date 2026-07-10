"use client";

import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import {
  ArrowLeftIcon,
  ArrowRightIcon,
  ChevronLeftIcon,
  EyeIcon,
  EyeOffIcon,
  HelpCircleIcon,
} from "@/components/icons";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import { fetchFollowUpQuestion } from "@/features/play/api";
import { AnnotatedTooltipText } from "@/features/play/components/keyword-tooltip-text";
import { getProgressPercent } from "@/features/play/play-logic";
import type { FollowUpQuestionDetail, PlaySession, ServerDifficulty } from "@/features/play/types";
import { ApiError } from "@/lib/api";

type FollowUpPageProps = {
  correct: boolean;
  correctStreak?: number;
  followUpQuestionId: number;
  questionIndex: number;
  session: PlaySession;
};

type LoadState =
  | { status: "loading" }
  | { status: "error" }
  | { status: "notReady" }
  | { status: "success"; data: FollowUpQuestionDetail };

/** 꼬리질문 자체 난이도(서버 EASY/MEDIUM/HARD) — play-logic의 difficultyLabels(low/medium/high)와는 스케일이 달라 별도 매핑. */
const followUpDifficultyLabels: Record<ServerDifficulty, string> = {
  EASY: "난이도 하",
  MEDIUM: "난이도 중",
  HARD: "난이도 상",
};

export function FollowUpPage({
  correct,
  correctStreak = 0,
  followUpQuestionId,
  questionIndex,
  session,
}: FollowUpPageProps) {
  const router = useRouter();
  const [revealed, setRevealed] = useState(false);
  const [state, setState] = useState<LoadState>({ status: "loading" });
  const total = session.questions.length;
  const isLastQuestion = questionIndex === total - 1;
  const nextHref = isLastQuestion ? "/" : `/play?question=${questionIndex + 1}`;
  const insightHref = `/insight?question=${questionIndex}&correct=${
    correct ? "true" : "false"
  }&streak=${correctStreak}`;

  const load = useCallback(async () => {
    setState({ status: "loading" });
    try {
      const data = await fetchFollowUpQuestion(followUpQuestionId);
      setState({ status: "success", data });
    } catch (error) {
      // 재발급까지 실패한 세션 무효(401)는 로그인으로 유도(frontend-api 규칙 3).
      if (error instanceof ApiError && error.status === 401) {
        router.replace("/login");
        return;
      }
      // 상세가 아직 없는 꼬리질문은 에러가 아니라 정상 상태 — "준비 중" 안내.
      if (error instanceof ApiError && error.code === "FOLLOW_UP_DETAIL_NOT_FOUND") {
        setState({ status: "notReady" });
        return;
      }
      setState({ status: "error" });
    }
  }, [followUpQuestionId, router]);

  useEffect(() => {
    void load();
  }, [load]);

  if (state.status === "loading") {
    return <FollowUpSkeleton />;
  }

  if (state.status === "notReady") {
    return (
      <main className="flex min-h-screen flex-col justify-center bg-bg px-4 py-6 text-ink sm:px-6">
        <div className="mx-auto w-full max-w-md">
          <EmptyState
            action={
              <a
                className="flex min-h-12 w-full items-center justify-center rounded-control border border-border bg-surface px-5 py-3 font-bold text-ink"
                href={insightHref}
              >
                해설로 돌아가기
              </a>
            }
            description="조금만 기다려 주시면 곧 만나볼 수 있어요."
            icon={<HelpCircleIcon className="h-6 w-6 text-ink-muted" />}
            title="꼬리 질문을 준비 중이에요"
          />
        </div>
      </main>
    );
  }

  if (state.status === "error") {
    return (
      <main className="flex min-h-screen flex-col justify-center bg-bg px-4 py-6 text-ink sm:px-6">
        <div className="mx-auto w-full max-w-md" role="alert">
          <EmptyState
            action={
              <Button onClick={() => void load()} variant="secondary">
                다시 시도
              </Button>
            }
            description="잠시 후 다시 시도해 주세요."
            title="꼬리 질문을 불러오지 못했어요"
          />
        </div>
      </main>
    );
  }

  const { data } = state;

  return (
    <main className="flex min-h-screen flex-col bg-bg px-4 py-5 text-ink sm:px-6">
      <div className="mx-auto flex w-full max-w-md flex-1 flex-col gap-4">
        <header className="rounded-card border border-border bg-surface p-4 shadow-card">
          <div className="flex items-center justify-between gap-3">
            <a
              aria-label="해설로 돌아가기"
              className="grid h-10 w-10 place-items-center rounded-chip border border-border bg-surface-muted text-ink"
              href={insightHref}
            >
              <ChevronLeftIcon className="h-5 w-5" />
            </a>
            <div className="min-w-0 flex-1">
              <p className="truncate text-xs font-semibold text-ink-muted">{session.unitTitle}</p>
              <h1 className="truncate text-base font-bold">꼬리 질문</h1>
            </div>
            <span className="inline-flex shrink-0 items-center gap-1.5 rounded-chip border border-border bg-surface px-3 py-1.5 text-xs font-bold text-ink">
              <span aria-hidden="true" className="h-1.5 w-1.5 rounded-chip bg-primary" />
              {followUpDifficultyLabels[data.difficulty]}
            </span>
          </div>
          <div className="mt-4">
            <div className="mb-2 flex items-center justify-between text-xs font-semibold text-ink-muted">
              <span>{data.sourceQuizNumber}번 문제에서 이어짐</span>
              <span>
                {questionIndex + 1}/{total}
              </span>
            </div>
            <Progress
              label="꼬리 질문 진행률"
              max={100}
              value={getProgressPercent(questionIndex, total)}
            />
          </div>
        </header>

        <section className="flex flex-1 flex-col rounded-card border border-border bg-surface-muted p-5 shadow-card">
          <div className="rounded-card border border-primary/20 bg-primary/5 px-5 py-5">
            <div className="flex items-center gap-2 text-primary">
              <HelpCircleIcon className="h-5 w-5" />
              <span className="text-sm font-bold">꼬리 질문</span>
            </div>
            <h2 className="mt-3 text-xl font-black leading-8 text-ink">{data.question}</h2>
          </div>

          <div className="mt-3 rounded-card bg-surface px-5 py-5 shadow-card">
            <p className="text-xs font-bold text-primary">한 줄 답</p>
            {revealed ? (
              <p className="mt-2.5 text-base font-medium leading-7 text-ink">
                <AnnotatedTooltipText annotated={data.oneLineAnswer} keywords={data.keywords} />
              </p>
            ) : (
              <div>
                <div aria-hidden="true" className="mt-3 space-y-2.5">
                  <Skeleton className="h-3 w-full rounded-chip" />
                  <Skeleton className="h-3 w-3/4 rounded-chip" />
                </div>
                <div className="mt-4 flex flex-col items-center gap-1.5 text-center">
                  <EyeOffIcon className="h-5 w-5 text-ink-muted" />
                  <span className="text-xs font-semibold text-ink-muted">
                    먼저 스스로 답을 떠올려 보세요.
                  </span>
                </div>
              </div>
            )}
          </div>

          <div className={revealed ? "mt-6" : "mt-6 opacity-50"}>
            <p className="px-1 text-sm font-bold text-ink">상세 정리</p>

            {data.blocks.map((block) => (
              // label은 서버 섹션 제목이라 중복 가능성이 있어 내용 일부를 더해 고유 key를 만든다.
              <div
                className="mt-2.5 rounded-control border border-border bg-surface px-4 py-4"
                key={`${block.label}-${block.content.text.slice(0, 32)}`}
              >
                <p className="text-sm font-bold text-ink">{block.label}</p>
                {revealed ? (
                  <p className="mt-2 text-sm leading-6 text-ink-muted">
                    <AnnotatedTooltipText annotated={block.content} keywords={data.keywords} />
                  </p>
                ) : (
                  <div aria-hidden="true" className="mt-3 space-y-2.5">
                    <Skeleton className="h-3 w-full rounded-chip" />
                    <Skeleton className="h-3 w-2/3 rounded-chip" />
                  </div>
                )}
              </div>
            ))}
          </div>

          <div className="mt-auto flex flex-col gap-2.5 pt-5">
            {revealed ? (
              <>
                <a
                  className="flex min-h-12 w-full items-center justify-center gap-2 rounded-control bg-primary px-5 py-3 font-bold text-primary-fg shadow-hero"
                  href={insightHref}
                >
                  <ArrowLeftIcon className="h-5 w-5" />
                  해설로 돌아가기
                </a>
                <a
                  className="flex min-h-12 w-full items-center justify-center gap-2 rounded-control border border-border bg-surface px-5 py-3 font-bold text-ink"
                  href={nextHref}
                >
                  {isLastQuestion ? "홈으로 돌아가기" : "다음 문제로"}
                  <ArrowRightIcon className="h-5 w-5" />
                </a>
              </>
            ) : (
              <>
                <button
                  className="flex min-h-12 w-full items-center justify-center gap-2 rounded-control bg-primary px-5 py-3 font-bold text-primary-fg shadow-hero"
                  onClick={() => setRevealed(true)}
                  type="button"
                >
                  <EyeIcon className="h-5 w-5" />답 확인하기
                </button>
                <a
                  className="flex min-h-12 w-full items-center justify-center rounded-control border border-border bg-surface px-5 py-3 font-bold text-ink-muted"
                  href={nextHref}
                >
                  이 질문 건너뛰기
                </a>
              </>
            )}
          </div>
        </section>
      </div>
    </main>
  );
}

/** 로딩 중 골격 — 헤더+본문 카드 레이아웃을 본뜬다(home-screen.tsx의 HomeSkeleton 패턴 참고). */
function FollowUpSkeleton() {
  return (
    <main className="flex min-h-screen flex-col bg-bg px-4 py-5 text-ink sm:px-6">
      <div
        aria-busy="true"
        aria-label="꼬리 질문 불러오는 중"
        className="mx-auto flex w-full max-w-md flex-1 flex-col gap-4"
        role="status"
      >
        <div className="rounded-card border border-border bg-surface p-4 shadow-card">
          <div className="flex items-center justify-between gap-3">
            <Skeleton className="h-10 w-10 rounded-chip" />
            <div className="min-w-0 flex-1 space-y-2">
              <Skeleton className="h-3 w-24" />
              <Skeleton className="h-4 w-32" />
            </div>
            <Skeleton className="h-7 w-20 rounded-chip" />
          </div>
          <div className="mt-4 space-y-2">
            <Skeleton className="h-3 w-full" />
            <Skeleton className="h-2 w-full rounded-chip" />
          </div>
        </div>
        <div className="flex-1 rounded-card border border-border bg-surface-muted p-5 shadow-card">
          <Skeleton className="h-24 w-full rounded-card" />
          <Skeleton className="mt-3 h-28 w-full rounded-card" />
        </div>
      </div>
    </main>
  );
}
