"use client";

import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Feedback } from "@/components/ui/feedback";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import { type ReviewContext, reviewInsightHref } from "@/features/history/review-params";
import { feedMascot } from "@/features/home/api";
import { CodeBlock } from "@/features/play/components/code-block";
import { getProgressPercent } from "@/features/play/play-logic";
import {
  difficultyLabels,
  getPlayQuestionKindLabel,
  isUnauthorized,
} from "@/features/play/quiz-shared";
import { getNextQuiz, getStepQuiz, type QuizNextResponse, submitQuizAnswer } from "@/lib/api/quiz";

type AnswerDraft = boolean | string | string[] | null;

const optionLabels = ["A", "B", "C", "D"];
const correctStreakStorageKeyPrefix = "thumbsup:insight-correct-streak:api-quiz";
const defaultStepTotal = 5;

type PlayPageProps = {
  /** 값이 있으면 완료 스텝 재풀이(복습) 모드 — 문제를 슬롯 순서로 받아 진행한다. */
  review?: ReviewContext | null;
};

export function PlayPage({ review }: PlayPageProps) {
  const router = useRouter();
  const [quiz, setQuiz] = useState<QuizNextResponse | null>(null);
  const [draft, setDraft] = useState<AnswerDraft>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);

  const reviewStep = review?.step ?? null;
  const reviewSlot = review?.slot ?? null;

  const totalCount = quiz?.totalCount ?? defaultStepTotal;
  const currentNumber = quiz?.slotOrder ?? 1;
  const submitEnabled = quiz ? canSubmitAnswer(quiz, draft) && !isSubmitting : false;

  const liveText = useMemo(() => {
    if (!quiz) {
      return "문제를 불러오는 중";
    }

    return `${totalCount}문제 중 ${currentNumber}번째, ${difficultyLabels[quiz.difficulty]}`;
  }, [currentNumber, quiz, totalCount]);

  useEffect(() => {
    let ignore = false;
    const requestKey = reloadKey;

    if (requestKey < 0) {
      return undefined;
    }

    async function loadQuiz() {
      setIsLoading(true);
      setError(null);
      setDraft(null);

      try {
        const nextQuiz =
          reviewStep !== null && reviewSlot !== null
            ? await getStepQuiz(reviewStep, reviewSlot)
            : await getNextQuiz();
        if (!ignore) {
          // 스트릭(연속 정답)은 일반 학습 세션에서만 추적 — 복습은 세션 진행으로 치지 않는다.
          if (reviewStep === null && nextQuiz.slotOrder === 1) {
            resetCorrectStreak(nextQuiz.stepOrder);
          }
          setQuiz(nextQuiz);
        }
      } catch (loadError) {
        if (isUnauthorized(loadError)) {
          router.replace("/login");
          return;
        }

        if (!ignore) {
          setError("문제를 불러오지 못했어요.");
        }
      } finally {
        if (!ignore) {
          setIsLoading(false);
        }
      }
    }

    void loadQuiz();

    return () => {
      ignore = true;
    };
  }, [reloadKey, router, reviewStep, reviewSlot]);

  async function submitAnswer() {
    if (!quiz || !submitEnabled) {
      return;
    }

    setIsSubmitting(true);
    setError(null);

    try {
      const result = await submitQuizAnswer(quiz.quizId, getSubmittedAnswers(quiz, draft));

      if (review) {
        // 복습: 오늘의 학습 스트릭·보리 포만감은 건드리지 않고, 복습 상태만 URL로 이어받는다.
        const correctAfter = review.correct + (result.isCorrect ? 1 : 0);
        const streakAfter = result.isCorrect ? review.streak + 1 : 0;
        router.push(
          reviewInsightHref(review, quiz.quizId, result.isCorrect, correctAfter, streakAfter),
        );
        return;
      }

      const nextStreak = updateCorrectStreak(quiz.stepOrder, result.isCorrect);
      if (currentNumber === totalCount) {
        void feedMascot().catch(() => {});
      }
      router.push(
        `/insight?quizId=${quiz.quizId}&correct=${result.isCorrect ? "true" : "false"}&streak=${nextStreak}`,
      );
    } catch (submitError) {
      if (isUnauthorized(submitError)) {
        router.replace("/login");
        return;
      }

      setError("정답을 확인하지 못했어요.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <main className="flex min-h-dvh flex-col bg-bg px-4 py-5 text-ink sm:px-6">
      <div className="mx-auto flex w-full max-w-md flex-1 flex-col gap-4">
        <header className="sticky top-4 z-10 rounded-card border border-border bg-surface p-4 shadow-card">
          <div className="flex items-center justify-between gap-3">
            <a
              className="grid h-10 w-10 place-items-center rounded-chip border border-border bg-surface-muted text-lg"
              aria-label={review ? "복습 목록으로 돌아가기" : "홈으로 돌아가기"}
              href={review ? "/history" : "/"}
            >
              ‹
            </a>
            <div className="min-w-0 flex-1">
              <p className="truncate text-xs font-semibold text-ink-muted">
                {review ? "복습" : "오늘의 학습"}
              </p>
              <h1 className="truncate text-base font-bold">
                {review ? review.topic || "문제 다시 풀기" : "문제 풀기"}
              </h1>
            </div>
          </div>
          <div className="mt-4">
            <div className="mb-2 flex items-center justify-between text-xs font-semibold text-ink-muted">
              {quiz ? (
                <>
                  <span>
                    {currentNumber}/{totalCount}
                  </span>
                  <span>{difficultyLabels[quiz.difficulty]}</span>
                </>
              ) : (
                <span>문제를 준비하고 있어요</span>
              )}
            </div>
            <Progress
              label="문제 진행률"
              max={100}
              value={quiz ? getProgressPercent(currentNumber - 1, totalCount) : 0}
            />
          </div>
          <p aria-live="polite" className="sr-only">
            {liveText}
          </p>
        </header>

        <section className="flex flex-1 flex-col rounded-card border border-border bg-surface-muted p-5 shadow-card">
          {isLoading ? <PlaySkeleton /> : null}
          {!isLoading && error ? (
            <Feedback tone="error" onRetry={() => setReloadKey((key) => key + 1)}>
              {error}
            </Feedback>
          ) : null}
          {!isLoading && !error && quiz ? (
            <>
              <QuestionRenderer
                draft={draft}
                isLocked={isSubmitting}
                onDraftChange={setDraft}
                quiz={quiz}
              />

              <div className="pt-4">
                <Button
                  className="w-full shadow-hero disabled:bg-surface-muted disabled:text-ink-muted disabled:shadow-none"
                  disabled={!submitEnabled}
                  loading={isSubmitting}
                  loadingText="채점 중"
                  onClick={submitAnswer}
                >
                  정답 확인
                </Button>
              </div>
            </>
          ) : null}
        </section>
      </div>
    </main>
  );
}

function PlaySkeleton() {
  return (
    <div className="flex flex-1 flex-col gap-5">
      <Skeleton className="h-5 w-20" />
      <Skeleton className="h-20 w-full" />
      <div className="mt-auto space-y-3">
        <Skeleton className="h-14 w-full" />
        <Skeleton className="h-14 w-full" />
      </div>
    </div>
  );
}

function QuestionRenderer({
  draft,
  isLocked,
  onDraftChange,
  quiz,
}: {
  draft: AnswerDraft;
  isLocked: boolean;
  onDraftChange: (draft: AnswerDraft) => void;
  quiz: QuizNextResponse;
}) {
  return (
    <div className="flex flex-1 flex-col">
      <div>
        <p className="text-xs font-bold text-ink-muted uppercase tracking-normal">
          {getQuestionKindLabel(quiz.type)}
        </p>
        <h2 className="mt-2 text-2xl font-black leading-8">{quiz.questionText}</h2>
      </div>

      <div className="mt-auto space-y-4 pt-6">
        {quiz.type === "OX" ? (
          <fieldset className="grid grid-cols-2 gap-3" aria-label="O 또는 X 선택">
            <OxButton
              disabled={isLocked}
              label="O"
              name={String(quiz.quizId)}
              selected={draft === true}
              tone="yes"
              onClick={() => onDraftChange(true)}
            />
            <OxButton
              disabled={isLocked}
              label="X"
              name={String(quiz.quizId)}
              selected={draft === false}
              tone="no"
              onClick={() => onDraftChange(false)}
            />
          </fieldset>
        ) : null}

        {quiz.type === "MULTIPLE_CHOICE" ? (
          <>
            {quiz.codeSnippet ? <CodeBlock code={quiz.codeSnippet} languageLabel="ts" /> : null}
            <fieldset className="space-y-3" aria-label="사지선다 선택지">
              {(quiz.choices ?? []).map((choice, index) => (
                <label
                  className={`flex min-h-14 w-full items-start gap-3 rounded-2xl border px-4 py-3 text-left text-sm font-semibold leading-6 transition ${
                    draft === String(choice.choiceId)
                      ? "border-primary bg-surface shadow-card"
                      : "border-border bg-surface"
                  }`}
                  key={choice.choiceId}
                >
                  <input
                    checked={draft === String(choice.choiceId)}
                    className="sr-only"
                    disabled={isLocked}
                    name={String(quiz.quizId)}
                    onChange={() => onDraftChange(String(choice.choiceId))}
                    type="radio"
                  />
                  <span className="grid h-7 w-7 shrink-0 place-items-center rounded-chip bg-ink text-xs text-primary-fg">
                    {optionLabels[index] ?? index + 1}
                  </span>
                  <span>{choice.content}</span>
                </label>
              ))}
            </fieldset>
          </>
        ) : null}

        {quiz.type === "KEYWORD_BLANK" ? (
          <KeywordBlankAnswer
            blankCount={quiz.blankCount ?? 1}
            codeSnippet={quiz.codeSnippet}
            disabled={isLocked}
            draft={Array.isArray(draft) ? draft : []}
            onDraftChange={onDraftChange}
          />
        ) : null}
      </div>
    </div>
  );
}

function OxButton({
  disabled,
  label,
  name,
  onClick,
  selected,
  tone,
}: {
  disabled: boolean;
  label: "O" | "X";
  name: string;
  onClick: () => void;
  selected: boolean;
  tone: "yes" | "no";
}) {
  const selectedClassName =
    tone === "yes"
      ? "border-ox-o bg-ox-o/10 text-success"
      : "border-danger bg-danger/10 text-danger";

  return (
    <label
      className={`flex min-h-28 items-center justify-center rounded-card border bg-surface text-5xl font-black transition ${
        selected ? selectedClassName : "border-border text-ink-muted"
      }`}
    >
      <input
        checked={selected}
        className="sr-only"
        disabled={disabled}
        name={name}
        onChange={onClick}
        type="radio"
      />
      {label}
    </label>
  );
}

function KeywordBlankAnswer({
  blankCount,
  codeSnippet,
  disabled,
  draft,
  onDraftChange,
}: {
  blankCount: number;
  codeSnippet: string | null;
  disabled: boolean;
  draft: string[];
  onDraftChange: (draft: AnswerDraft) => void;
}) {
  function updateAnswer(index: number, value: string) {
    const nextDraft = Array.from(
      { length: blankCount },
      (_, draftIndex) => draft[draftIndex] ?? "",
    );
    nextDraft[index] = value;
    onDraftChange(nextDraft);
  }

  return (
    <>
      {codeSnippet ? <CodeBlock code={codeSnippet} languageLabel="pseudo" /> : null}
      <fieldset className="space-y-3" aria-label="키워드 빈칸 답안">
        {getBlankSlots(blankCount).map((slot) => (
          <label className="block" key={`blank-${slot}`}>
            <span className="text-sm font-bold text-ink">핵심 키워드 {slot}</span>
            <input
              aria-label={`핵심 키워드 ${slot}`}
              autoCapitalize="off"
              autoComplete="off"
              autoCorrect="off"
              className="mt-2 min-h-12 w-full rounded-control border border-border bg-surface px-4 text-base font-semibold outline-none transition focus:border-primary disabled:text-ink-muted"
              disabled={disabled}
              onChange={(event) => updateAnswer(slot - 1, event.target.value)}
              placeholder="키워드를 입력하세요"
              value={draft[slot - 1] ?? ""}
            />
          </label>
        ))}
      </fieldset>
    </>
  );
}

function getBlankSlots(blankCount: number) {
  return Array.from({ length: blankCount }, (_, index) => index + 1);
}

const getQuestionKindLabel = getPlayQuestionKindLabel;

function canSubmitAnswer(quiz: QuizNextResponse, draft: AnswerDraft) {
  if (quiz.type === "OX") {
    return typeof draft === "boolean";
  }

  if (quiz.type === "MULTIPLE_CHOICE") {
    return typeof draft === "string" && draft.length > 0;
  }

  return (
    Array.isArray(draft) &&
    draft.length === (quiz.blankCount ?? 1) &&
    draft.every((answer) => answer.trim().length > 0)
  );
}

function getSubmittedAnswers(quiz: QuizNextResponse, draft: AnswerDraft) {
  if (quiz.type === "OX") {
    return [draft === true ? "O" : "X"];
  }

  if (quiz.type === "MULTIPLE_CHOICE") {
    return [String(draft ?? "")];
  }

  return Array.isArray(draft) ? draft.map((answer) => answer.trim()) : [];
}

function getCorrectStreakStorageKey(stepOrder: number) {
  return `${correctStreakStorageKeyPrefix}:${stepOrder}`;
}

function resetCorrectStreak(stepOrder: number) {
  window.localStorage.setItem(getCorrectStreakStorageKey(stepOrder), "0");
}

function readCorrectStreak(stepOrder: number) {
  const value = Number(window.localStorage.getItem(getCorrectStreakStorageKey(stepOrder)) ?? 0);

  return Number.isFinite(value) ? Math.max(0, Math.trunc(value)) : 0;
}

function updateCorrectStreak(stepOrder: number, correct: boolean) {
  const nextStreak = correct ? readCorrectStreak(stepOrder) + 1 : 0;

  window.localStorage.setItem(getCorrectStreakStorageKey(stepOrder), String(nextStreak));

  return nextStreak;
}
