"use client";

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
import { getCelebration } from "@/features/play/celebration-logic";
import {
  type CompletionSummary,
  clampCompletion,
  isPerfectCompletion,
} from "@/features/play/completion-params";
import { CompletionCard } from "@/features/play/components/completion-card";
import { FanfareOverlay } from "@/features/play/components/fanfare-overlay";
import {
  getKeywordDescriptionMap,
  KeywordTooltipText,
} from "@/features/play/components/keyword-tooltip-text";
import { VerdictBanner } from "@/features/play/components/verdict-banner";
import { buildPlayHref, COURSE_LIST_PATH } from "@/features/play/course-params";
import { getProgressPercent } from "@/features/play/play-logic";
import {
  difficultyLabels,
  getInsightQuestionKindLabel,
  isUnauthorized,
} from "@/features/play/quiz-shared";
import { usePrefersReducedMotion } from "@/features/play/use-prefers-reduced-motion";
import {
  type AnnotatedText,
  getQuizExplanation,
  type QuizExplanationResponse,
} from "@/lib/api/quiz";

type InsightPageProps = {
  /** 값이 있으면 이 문제로 스텝 한 판이 끝났다는 뜻 — 완주 요약 카드를 그린다. */
  completion?: CompletionSummary | null;
  correct: boolean;
  correctStreak?: number;
  /** 코스 탭에서 진입한 세션이면 실린다 — "다음 문제"가 같은 코스로 이어지게 한다. */
  courseId?: number;
  quizId: number | null;
  /** 값이 있으면 완료 스텝 재풀이(복습) 모드 — 꼬리질문 대신 다음 슬롯/완료로 진행한다. */
  review?: ReviewContext | null;
  /** 첫 오답 뒤 재도전(이슈 63)으로 맞힌 경우 — 콤보와 별개로 특별 칭찬을 준다. */
  wasRetry?: boolean;
};

export function InsightPage({
  completion = null,
  correct,
  correctStreak = 0,
  courseId,
  quizId,
  review,
  wasRetry = false,
}: InsightPageProps) {
  const prefersReducedMotion = usePrefersReducedMotion();
  const router = useRouter();
  const [explanation, setExplanation] = useState<QuizExplanationResponse | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
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
  const isLastQuestion = explanation ? explanation.currentNumber >= explanation.totalCount : false;
  // 코스 탭에서 들어온 세션이면 다음 문제로 같은 코스로 이어지고, 완주 뒤에는 코스 목록으로 돌아간다.
  const playHref = buildPlayHref(courseId);
  const completionDestination = getCompletionDestination(courseId);
  // 보상 연출은 전부 이 화면에서 터진다 — 풀이 화면(S3)은 조작감만 맡는다.
  // 난이도는 해설 응답에서 오므로, 로딩이 끝나기 전엔 기본값으로 계산해도 화면에 쓰이지 않는다.
  const celebration = getCelebration({
    combo: review?.streak ?? correctStreak,
    correct,
    difficulty: explanation?.difficulty ?? "EASY",
    prefersReducedMotion,
    quizId: quizId ?? 0,
    wasRetry,
  });
  // 팡파레는 이제 "연속 3정답"이 아니라 완주 퍼펙트에만 터진다(이슈 211).
  // 3콤보는 퀴즈 화면에서 이미 컨페티로 축하했으므로 여기서 또 터뜨리면 중복이다.
  const isPerfectRun =
    completion !== null &&
    explanation !== null &&
    isPerfectCompletion(
      clampCompletion(completion, explanation.totalCount),
      explanation.totalCount,
    );

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

  return (
    <main className="relative flex min-h-screen flex-col bg-bg px-4 py-5 text-ink sm:px-6">
      {isPerfectRun && quizId !== null ? <FanfareOverlay playKey={`daily:${quizId}`} /> : null}

      <div className="mx-auto flex w-full max-w-md flex-1 flex-col gap-4">
        <header className="rounded-card border border-border bg-surface p-4 shadow-card">
          <div className="flex items-center justify-between gap-3">
            <a
              aria-label={review ? "복습 목록으로 돌아가기" : "문제로 돌아가기"}
              className="grid h-10 w-10 place-items-center rounded-chip border border-border bg-surface-muted text-lg"
              href={review ? "/history/review" : playHref}
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
              <VerdictBanner celebration={celebration} correct={correct} />

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

              {completion ? (
                <CompletionCard summary={completion} totalCount={explanation.totalCount} />
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
                        href={getFollowUpHref(
                          quizId,
                          correct,
                          correctStreak,
                          primaryFollowUpQuestion.followUpQuestionId,
                          courseId,
                        )}
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
                      href={isLastQuestion ? completionDestination.href : playHref}
                    >
                      {isLastQuestion ? completionDestination.label : "다음 문제 풀기"}
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

/** 완주 후 목적지 — 코스 탭에서 진입했으면 코스 목록으로, 아니면 홈으로 돌아간다. */
function getCompletionDestination(courseId: number | undefined) {
  return courseId
    ? { href: COURSE_LIST_PATH, label: "코스 목록으로 가기" }
    : { href: "/", label: "홈으로 가기" };
}

/** 꼬리 질문 화면 URL — courseId가 있으면 그대로 실어 해설로 돌아올 때 코스를 유지한다. */
function getFollowUpHref(
  quizId: number | null,
  correct: boolean,
  correctStreak: number,
  followUpQuestionId: number,
  courseId: number | undefined,
) {
  const params = new URLSearchParams({
    quizId: String(quizId ?? ""),
    correct: correct ? "true" : "false",
    streak: String(correctStreak),
    fq: String(followUpQuestionId),
  });
  if (courseId) {
    params.set("courseId", String(courseId));
  }

  return `/follow-up?${params.toString()}`;
}

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
