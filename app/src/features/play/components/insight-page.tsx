"use client";

import { type DotLottie, DotLottieReact } from "@lottiefiles/dotlottie-react";
import { useEffect, useState } from "react";
import { HelpCircleIcon } from "@/components/icons";
import { Progress } from "@/components/ui/progress";
import { CodeBlock } from "@/features/play/components/code-block";
import { KeywordTooltipText } from "@/features/play/components/keyword-tooltip-text";
import { getDifficultyLabel, getProgressPercent } from "@/features/play/play-logic";
import type { PlayQuestion, PlaySession } from "@/features/play/types";

const FANFARE_SRC = "/lottie/fanfare.lottie";

type InsightPageProps = {
  correct: boolean;
  correctStreak?: number;
  questionIndex: number;
  session: PlaySession;
};

export function InsightPage({
  correct,
  correctStreak = 0,
  questionIndex,
  session,
}: InsightPageProps) {
  const [fanfarePlayer, setFanfarePlayer] = useState<DotLottie | null>(null);
  const [dismissedFanfareKey, setDismissedFanfareKey] = useState<string | null>(null);
  const question = session.questions[questionIndex];
  const total = session.questions.length;
  const isLastQuestion = questionIndex === total - 1;
  const nextHref = isLastQuestion ? "/" : `/play?question=${questionIndex + 1}`;
  const fanfareKey = correct && correctStreak >= 3 ? `${questionIndex}:${correctStreak}` : null;
  const showFanfare = fanfareKey !== null && dismissedFanfareKey !== fanfareKey;
  const summaryItems = getSummaryItems(question.insight.summary.slice(0, 3));

  useEffect(() => {
    if (!fanfarePlayer) {
      return undefined;
    }

    function dismissFanfare() {
      setDismissedFanfareKey(fanfareKey);
    }

    fanfarePlayer.addEventListener("complete", dismissFanfare);

    return () => {
      fanfarePlayer.removeEventListener("complete", dismissFanfare);
    };
  }, [fanfareKey, fanfarePlayer]);

  return (
    <main className="relative flex min-h-screen flex-col bg-bg px-4 py-5 text-ink sm:px-6">
      {showFanfare ? (
        <div
          aria-hidden="true"
          className="pointer-events-none fixed inset-0 z-50"
          data-src={FANFARE_SRC}
          data-testid="lottie-fanfare"
        >
          <DotLottieReact
            autoplay
            className="h-screen w-screen"
            dotLottieRefCallback={setFanfarePlayer}
            loop={false}
            src={FANFARE_SRC}
          />
        </div>
      ) : null}

      <div className="mx-auto flex w-full max-w-md flex-1 flex-col gap-4">
        <header className="rounded-card border border-border bg-surface p-4 shadow-card">
          <div className="flex items-center justify-between gap-3">
            <a
              aria-label="문제로 돌아가기"
              className="grid h-10 w-10 place-items-center rounded-chip border border-border bg-surface-muted text-lg"
              href={`/play?question=${questionIndex}`}
            >
              ‹
            </a>
            <div className="min-w-0 flex-1">
              <p className="truncate text-xs font-semibold text-ink-muted">{session.courseTitle}</p>
              <h1 className="truncate text-base font-bold">문제 해설</h1>
            </div>
            <span
              className={`rounded-chip px-3 py-1.5 text-xs font-bold ${
                correct ? "bg-success/10 text-success" : "bg-danger/10 text-danger"
              }`}
            >
              {correct ? "정답" : "오답"}
            </span>
          </div>
          <div className="mt-4">
            <div className="mb-2 flex items-center justify-between text-xs font-semibold text-ink-muted">
              <span>
                {questionIndex + 1}/{total}
              </span>
              <span>{getDifficultyLabel(question.difficulty)}</span>
            </div>
            <Progress
              label="해설 진행률"
              max={100}
              value={getProgressPercent(questionIndex, total)}
            />
          </div>
        </header>

        <section className="flex flex-1 flex-col rounded-card border border-border bg-surface-muted p-5 shadow-card">
          <div
            className={`rounded-control border px-4 py-4 ${
              correct
                ? "border-success/20 bg-success/10 text-success"
                : "border-danger/20 bg-danger/10 text-danger"
            }`}
          >
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="text-sm font-black">{correct ? "정답이에요" : "오답이에요"}</p>
                <p className="mt-1 text-sm font-semibold leading-6 text-ink-muted">
                  {correct
                    ? "핵심을 잘 짚었어요. 바로 개념을 정리해볼게요."
                    : "괜찮아요. 틀린 지점을 먼저 짚고 넘어갈게요."}
                </p>
              </div>
              {correct ? (
                <span className="rounded-chip bg-surface px-3 py-1.5 text-xs font-black text-success">
                  +10P
                </span>
              ) : null}
            </div>
          </div>

          {!correct ? (
            <div className="mt-4 rounded-control border border-danger/20 bg-surface px-4 py-4">
              <p className="text-sm font-bold text-danger">왜 틀렸는지</p>
              <p className="mt-2 text-sm leading-6 text-ink-muted">
                <KeywordTooltipText
                  keywords={question.insight.keywords}
                  text={question.insight.wrongReason}
                />
              </p>
            </div>
          ) : null}

          <div className="mt-4 rounded-control border border-border bg-surface px-4 py-4">
            <p className="text-sm font-bold text-ink">핵심 3줄</p>
            <ol aria-label="핵심 3줄" className="mt-3 space-y-2">
              {summaryItems.map((item) => (
                <li className="flex gap-3 text-sm leading-6 text-ink-muted" key={item.key}>
                  <span className="grid h-6 w-6 shrink-0 place-items-center rounded-chip bg-ink text-xs font-black text-primary-fg">
                    {item.position}
                  </span>
                  <span>
                    <KeywordTooltipText keywords={question.insight.keywords} text={item.line} />
                  </span>
                </li>
              ))}
            </ol>
          </div>

          <div className="mt-4">
            <p className="text-xs font-bold text-ink-muted uppercase tracking-normal">
              {getQuestionKindLabel(question)}
            </p>
            <h2 className="mt-2 text-2xl font-black leading-8">{question.prompt}</h2>
          </div>

          <div className="mt-4 rounded-control border border-border bg-surface px-4 py-4">
            <p className="text-sm font-bold text-ink">해설</p>
            <p className="mt-2 text-sm leading-6 text-ink-muted">
              <KeywordTooltipText
                keywords={question.insight.keywords}
                text={question.explanation}
              />
            </p>
          </div>

          {question.insight.codeExample ? (
            <div className="mt-4 rounded-control border border-border bg-surface px-4 py-4">
              <p className="text-sm font-bold text-ink">코드 적용 예시</p>
              <div className="mt-3">
                <CodeBlock
                  code={question.insight.codeExample.source}
                  languageLabel={question.insight.codeExample.language}
                />
              </div>
              <p className="mt-3 text-sm leading-6 text-ink-muted">
                <KeywordTooltipText
                  keywords={question.insight.keywords}
                  text={question.insight.codeExample.description}
                />
              </p>
            </div>
          ) : null}

          <div className="mt-4 rounded-control border border-border bg-surface px-4 py-4">
            <p className="text-sm font-bold text-ink">실무 사용처</p>
            <p className="mt-2 text-sm leading-6 text-ink-muted">
              <KeywordTooltipText
                keywords={question.insight.keywords}
                text={question.insight.usageExample}
              />
            </p>
          </div>

          <div className="mt-4 flex items-center justify-between rounded-control border border-dashed border-border px-4 py-3 text-sm text-ink-muted">
            <span>레퍼런스</span>
            <span className="font-semibold text-ink">{question.insight.referenceLabel}</span>
          </div>

          <div className="mt-auto flex flex-col gap-2.5 pt-5">
            {question.followUp ? (
              <a
                className="flex min-h-12 w-full items-center justify-center gap-2 rounded-control bg-primary px-5 py-3 font-bold text-primary-fg shadow-hero"
                href={`/follow-up?question=${questionIndex}&correct=${
                  correct ? "true" : "false"
                }&streak=${correctStreak}`}
              >
                <HelpCircleIcon className="h-5 w-5" />
                꼬리 질문 풀기
              </a>
            ) : null}
            <a
              className={
                question.followUp
                  ? "flex min-h-12 w-full items-center justify-center rounded-control border border-border bg-surface px-5 py-3 font-bold text-ink"
                  : "flex min-h-12 w-full items-center justify-center rounded-control bg-primary px-5 py-3 font-bold text-primary-fg shadow-hero"
              }
              href={nextHref}
            >
              {isLastQuestion ? "홈으로 돌아가기" : "다음 문제 풀기"}
            </a>
          </div>
        </section>
      </div>
    </main>
  );
}

function getQuestionKindLabel(question: PlayQuestion) {
  if (question.kind === "ox") {
    return "OX 해설";
  }

  if (question.kind === "multiple-choice") {
    return "사지선다 해설";
  }

  return "키워드 빈칸 해설";
}

function getSummaryItems(lines: string[]) {
  const occurrenceByLine = new Map<string, number>();

  return lines.map((line, index) => {
    const occurrence = occurrenceByLine.get(line) ?? 0;
    occurrenceByLine.set(line, occurrence + 1);

    return {
      key: `${line}-${occurrence}`,
      line,
      position: index + 1,
    };
  });
}
