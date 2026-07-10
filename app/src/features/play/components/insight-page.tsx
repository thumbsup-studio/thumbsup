"use client";

import { type DotLottie, DotLottieReact } from "@lottiefiles/dotlottie-react";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { HelpCircleIcon } from "@/components/icons";
import { Feedback } from "@/components/ui/feedback";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import {
  isLastReviewSlot,
  type ReviewContext,
  reviewDoneHref,
  reviewNextPlayHref,
} from "@/features/history/review-params";
import {
  getKeywordDescriptionMap,
  KeywordTooltipText,
} from "@/features/play/components/keyword-tooltip-text";
import { getProgressPercent } from "@/features/play/play-logic";
import {
  difficultyLabels,
  getInsightQuestionKindLabel,
  isUnauthorized,
} from "@/features/play/quiz-shared";
import {
  type AnnotatedText,
  getQuizExplanation,
  type QuizExplanationResponse,
} from "@/lib/api/quiz";

const FANFARE_SRC = "/lottie/fanfare.lottie";

type InsightPageProps = {
  correct: boolean;
  correctStreak?: number;
  quizId: number | null;
  /** 값이 있으면 완료 스텝 재풀이(복습) 모드 — 꼬리질문 대신 다음 슬롯/완료로 진행한다. */
  review?: ReviewContext | null;
};

export function InsightPage({ correct, correctStreak = 0, quizId, review }: InsightPageProps) {
  const router = useRouter();
  const [explanation, setExplanation] = useState<QuizExplanationResponse | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [fanfarePlayer, setFanfarePlayer] = useState<DotLottie | null>(null);
  const [dismissedFanfareKey, setDismissedFanfareKey] = useState<string | null>(null);

  const fanfareKey =
    quizId !== null && correct && correctStreak >= 3 ? `${quizId}:${correctStreak}` : null;
  const showFanfare =
    review == null &&
    fanfareKey !== null &&
    dismissedFanfareKey !== fanfareKey &&
    !isLoading &&
    !error &&
    explanation !== null;
  const keywordDict = useMemo(
    () => getKeywordDescriptionMap(explanation?.keywords ?? []),
    [explanation],
  );
  const summaryItems = useMemo(
    () => getSummaryItems(explanation?.explanationSummary ?? []),
    [explanation],
  );
  const primaryFollowUpQuestion = getPrimaryFollowUpQuestion(explanation?.followUpQuestions ?? []);
  const reviewNextHref = review
    ? isLastReviewSlot(review)
      ? reviewDoneHref(review)
      : reviewNextPlayHref(review)
    : null;

  useEffect(() => {
    if (quizId === null) {
      setIsLoading(false);
      setError("해설을 불러오지 못했어요.");
      return;
    }

    let ignore = false;
    const explanationQuizId = quizId;
    const requestKey = reloadKey;

    if (requestKey < 0) {
      return undefined;
    }

    async function loadExplanation() {
      setIsLoading(true);
      setError(null);

      try {
        const nextExplanation = await getQuizExplanation(explanationQuizId);
        if (!ignore) {
          setExplanation(nextExplanation);
        }
      } catch (loadError) {
        if (isUnauthorized(loadError)) {
          router.replace("/login");
          return;
        }

        if (!ignore) {
          setError("해설을 불러오지 못했어요.");
        }
      } finally {
        if (!ignore) {
          setIsLoading(false);
        }
      }
    }

    void loadExplanation();

    return () => {
      ignore = true;
    };
  }, [quizId, reloadKey, router]);

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
              aria-label={review ? "복습 목록으로 돌아가기" : "문제로 돌아가기"}
              className="grid h-10 w-10 place-items-center rounded-chip border border-border bg-surface-muted text-lg"
              href={review ? "/history" : "/play"}
            >
              ‹
            </a>
            <div className="min-w-0 flex-1">
              <p className="truncate text-xs font-semibold text-ink-muted">
                {explanation?.courseTitle ?? "오늘의 학습"}
              </p>
              <h1 className="truncate text-base font-bold">
                {explanation?.unitTitle ?? "문제 해설"}
              </h1>
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
              {explanation ? (
                <>
                  <span>
                    {explanation.currentNumber}/{explanation.totalCount}
                  </span>
                  <span>{difficultyLabels[explanation.difficulty]}</span>
                </>
              ) : (
                <span>해설을 준비하고 있어요</span>
              )}
            </div>
            <Progress
              label="해설 진행률"
              max={100}
              value={
                explanation
                  ? getProgressPercent(explanation.currentNumber - 1, explanation.totalCount)
                  : 0
              }
            />
          </div>
        </header>

        <section className="flex flex-1 flex-col rounded-card border border-border bg-surface-muted p-5 shadow-card">
          {isLoading ? <InsightSkeleton /> : null}
          {!isLoading && error ? (
            <Feedback tone="error" onRetry={() => setReloadKey((key) => key + 1)}>
              {error}
            </Feedback>
          ) : null}
          {!isLoading && !error && explanation ? (
            <>
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
                  <AnnotatedParagraph
                    className="mt-2 text-sm leading-6 text-ink-muted whitespace-pre-line"
                    dict={keywordDict}
                    node={explanation.wrongAnswerExplanation}
                  />
                </div>
              ) : null}

              <div className="mt-4 rounded-control border border-border bg-surface px-4 py-4">
                <p className="text-sm font-bold text-ink">핵심 정리</p>
                <ol aria-label="핵심 정리" className="mt-3 space-y-2">
                  {summaryItems.map((summary) => (
                    <li className="flex gap-3 text-sm leading-6 text-ink-muted" key={summary.key}>
                      <span className="grid h-6 w-6 shrink-0 place-items-center rounded-chip bg-ink text-xs font-black text-primary-fg">
                        {summary.position}
                      </span>
                      <span>
                        <KeywordTooltipText dict={keywordDict} node={summary.node} />
                      </span>
                    </li>
                  ))}
                </ol>
              </div>

              <div className="mt-4">
                <p className="text-xs font-bold text-ink-muted uppercase tracking-normal">
                  {getQuestionKindLabel(explanation.type)}
                </p>
                <h2 className="mt-2 text-2xl font-black leading-8">{explanation.questionText}</h2>
              </div>

              {explanation.explanationExample ? (
                <div className="mt-4 rounded-control border border-border bg-surface px-4 py-4">
                  <p className="text-sm font-bold text-ink">적용 예시</p>
                  <AnnotatedParagraph
                    className="mt-2 text-sm leading-6 text-ink-muted whitespace-pre-line"
                    dict={keywordDict}
                    node={explanation.explanationExample}
                  />
                </div>
              ) : null}

              <div className="mt-auto flex flex-col gap-2.5 pt-5">
                {review && reviewNextHref ? (
                  <a
                    className="flex min-h-12 w-full items-center justify-center rounded-control bg-primary px-5 py-3 font-bold text-primary-fg shadow-hero"
                    href={reviewNextHref}
                  >
                    {isLastReviewSlot(review) ? "복습 완료" : "다음 문제"}
                  </a>
                ) : (
                  <>
                    {primaryFollowUpQuestion ? (
                      <a
                        className="flex min-h-12 w-full items-center justify-center gap-2 rounded-control bg-primary px-5 py-3 font-bold text-primary-fg shadow-hero"
                        href={`/follow-up?correct=${
                          correct ? "true" : "false"
                        }&streak=${correctStreak}&fq=${primaryFollowUpQuestion.followUpQuestionId}`}
                      >
                        <HelpCircleIcon className="h-5 w-5" />
                        꼬리 질문 풀기
                      </a>
                    ) : (
                      <button
                        className="flex min-h-12 w-full cursor-not-allowed items-center justify-center gap-2 rounded-control border border-border bg-surface-muted px-5 py-3 font-bold text-ink-muted"
                        disabled
                        type="button"
                      >
                        <HelpCircleIcon className="h-5 w-5" />
                        꼬리 질문 준비 중
                      </button>
                    )}
                    <a
                      className={
                        primaryFollowUpQuestion
                          ? "flex min-h-12 w-full items-center justify-center rounded-control border border-border bg-surface px-5 py-3 font-bold text-ink"
                          : "flex min-h-12 w-full items-center justify-center rounded-control bg-primary px-5 py-3 font-bold text-primary-fg shadow-hero"
                      }
                      href="/play"
                    >
                      다음 문제 풀기
                    </a>
                  </>
                )}
              </div>
            </>
          ) : null}
        </section>
      </div>
    </main>
  );
}

function InsightSkeleton() {
  return (
    <div className="flex flex-1 flex-col gap-4">
      <Skeleton className="h-20 w-full" />
      <Skeleton className="h-32 w-full" />
      <Skeleton className="h-24 w-full" />
    </div>
  );
}

function AnnotatedParagraph({
  className,
  dict,
  node,
}: {
  className: string;
  dict: Map<string, string>;
  node: AnnotatedText;
}) {
  return (
    <p className={className}>
      <KeywordTooltipText dict={dict} node={node} />
    </p>
  );
}

const getQuestionKindLabel = getInsightQuestionKindLabel;

function getSummaryItems(lines: AnnotatedText[]) {
  const occurrences = new Map<string, number>();

  return lines.map((node, index) => {
    const count = occurrences.get(node.text) ?? 0;
    occurrences.set(node.text, count + 1);

    return {
      key: `${node.text}:${count}`,
      node,
      position: index + 1,
    };
  });
}

function getPrimaryFollowUpQuestion(
  followUpQuestions: QuizExplanationResponse["followUpQuestions"],
) {
  return (
    followUpQuestions.find((followUpQuestion) => followUpQuestion.isPrimary) ??
    followUpQuestions[0] ??
    null
  );
}
