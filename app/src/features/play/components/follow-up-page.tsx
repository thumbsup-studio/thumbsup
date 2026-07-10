"use client";

import { useState } from "react";
import {
  ArrowLeftIcon,
  ArrowRightIcon,
  ChevronLeftIcon,
  EyeIcon,
  EyeOffIcon,
  HelpCircleIcon,
} from "@/components/icons";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import { KeywordTooltipText } from "@/features/play/components/keyword-tooltip-text";
import { getDifficultyLabel, getProgressPercent } from "@/features/play/play-logic";
import type { FollowUpQuestion, PlaySession } from "@/features/play/types";

type FollowUpPageProps = {
  correct: boolean;
  correctStreak?: number;
  followUp: FollowUpQuestion;
  questionIndex: number;
  session: PlaySession;
};

export function FollowUpPage({
  correct,
  correctStreak = 0,
  followUp,
  questionIndex,
  session,
}: FollowUpPageProps) {
  const [revealed, setRevealed] = useState(false);
  const total = session.questions.length;
  const isLastQuestion = questionIndex === total - 1;
  const nextHref = isLastQuestion ? "/" : `/play?question=${questionIndex + 1}`;
  const insightHref = `/insight?question=${questionIndex}&correct=${
    correct ? "true" : "false"
  }&streak=${correctStreak}`;

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
              <p className="truncate text-xs font-semibold text-ink-muted">{followUp.category}</p>
              <h1 className="truncate text-base font-bold">꼬리 질문</h1>
            </div>
            <span className="inline-flex shrink-0 items-center gap-1.5 rounded-chip border border-border bg-surface px-3 py-1.5 text-xs font-bold text-ink">
              <span aria-hidden="true" className="h-1.5 w-1.5 rounded-chip bg-primary" />
              {getDifficultyLabel(followUp.difficulty)}
            </span>
          </div>
          <div className="mt-4">
            <div className="mb-2 flex items-center justify-between text-xs font-semibold text-ink-muted">
              <span>{questionIndex + 1}번 문제에서 이어짐</span>
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
            <h2 className="mt-3 text-xl font-black leading-8 text-ink">{followUp.question}</h2>
          </div>

          <div className="mt-3 rounded-card bg-surface px-5 py-5 shadow-card">
            <p className="text-xs font-bold text-primary">한 줄 답</p>
            {revealed ? (
              <p className="mt-2.5 text-base font-medium leading-7 text-ink">
                <KeywordTooltipText keywords={followUp.keywords} text={followUp.oneLineAnswer} />
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

            <div className="mt-2.5 rounded-control border border-border bg-surface px-4 py-4">
              <p className="text-sm font-bold text-ink">해설</p>
              {revealed ? (
                <p className="mt-2 text-sm leading-6 text-ink-muted">
                  <KeywordTooltipText keywords={followUp.keywords} text={followUp.explanation} />
                </p>
              ) : (
                <div aria-hidden="true" className="mt-3 space-y-2.5">
                  <Skeleton className="h-3 w-full rounded-chip" />
                  <Skeleton className="h-3 w-full rounded-chip" />
                  <Skeleton className="h-3 w-2/3 rounded-chip" />
                </div>
              )}
            </div>

            <div className="mt-3 rounded-control border border-border bg-surface px-4 py-4">
              <p className="text-sm font-bold text-ink">실무 사용처</p>
              {revealed ? (
                <p className="mt-2 text-sm leading-6 text-ink-muted">
                  <KeywordTooltipText keywords={followUp.keywords} text={followUp.usageExample} />
                </p>
              ) : (
                <div aria-hidden="true" className="mt-3 space-y-2.5">
                  <Skeleton className="h-3 w-full rounded-chip" />
                  <Skeleton className="h-3 w-1/2 rounded-chip" />
                </div>
              )}
            </div>
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
