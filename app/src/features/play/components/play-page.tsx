"use client";

import { useMemo, useState } from "react";
import { Progress } from "@/components/ui/progress";
import { CodeBlock } from "@/features/play/components/code-block";
import {
  canSubmitAnswer,
  clampQuestionIndex,
  getDifficultyLabel,
  getProgressPercent,
  gradeMockAnswer,
} from "@/features/play/play-logic";
import type { AnswerDraft, PlayQuestion, PlaySession } from "@/features/play/types";

type PlayPageProps = {
  initialQuestionIndex?: number;
  onInsightNavigate?: (href: string) => void;
  session: PlaySession;
};

const optionLabels = ["A", "B", "C", "D"];

export function PlayPage({
  initialQuestionIndex = 0,
  onInsightNavigate = (href) => {
    window.location.assign(href);
  },
  session,
}: PlayPageProps) {
  const [currentIndex] = useState(() =>
    clampQuestionIndex(initialQuestionIndex, session.questions.length),
  );
  const [draft, setDraft] = useState<AnswerDraft>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const question = session.questions[currentIndex];
  const total = session.questions.length;
  const progressPercent = getProgressPercent(currentIndex, total);
  const submitEnabled = canSubmitAnswer(question, draft) && !isSubmitting;

  const liveText = useMemo(
    () => `${total}문제 중 ${currentIndex + 1}번째, ${getDifficultyLabel(question.difficulty)}`,
    [currentIndex, question.difficulty, total],
  );

  function submitAnswer() {
    if (!submitEnabled) {
      return;
    }

    setIsSubmitting(true);
    window.setTimeout(() => {
      const result = gradeMockAnswer(question, draft);
      setIsSubmitting(false);
      onInsightNavigate(
        `/insight?question=${currentIndex}&correct=${result.correct ? "true" : "false"}`,
      );
    }, 220);
  }

  return (
    <main className="flex min-h-screen flex-col bg-bg px-4 py-5 text-ink sm:px-6">
      <div className="mx-auto flex w-full max-w-md flex-1 flex-col gap-4">
        <header className="sticky top-4 z-10 rounded-card border border-border bg-surface p-4 shadow-card">
          <div className="flex items-center justify-between gap-3">
            <a
              className="grid h-10 w-10 place-items-center rounded-chip border border-border bg-surface-muted text-lg"
              aria-label="이전 문제로 돌아가기"
              href={currentIndex === 0 ? "/" : `/play?question=${currentIndex - 1}`}
            >
              ‹
            </a>
            <div className="min-w-0 flex-1">
              <p className="truncate text-xs font-semibold text-ink-muted">{session.courseTitle}</p>
              <h1 className="truncate text-base font-bold">{session.unitTitle}</h1>
            </div>
          </div>
          <div className="mt-4">
            <div className="mb-2 flex items-center justify-between text-xs font-semibold text-ink-muted">
              <span>
                {currentIndex + 1}/{total}
              </span>
              <span>{getDifficultyLabel(question.difficulty)}</span>
            </div>
            <Progress label="문제 진행률" max={100} value={progressPercent} />
          </div>
          <p aria-live="polite" className="sr-only">
            {liveText}
          </p>
        </header>

        <section className="flex flex-1 flex-col rounded-card border border-border bg-surface-muted p-5 shadow-card">
          <QuestionRenderer
            draft={draft}
            isLocked={isSubmitting}
            onDraftChange={setDraft}
            question={question}
          />

          <div className="pt-4">
            <button
              className="min-h-12 w-full rounded-control bg-primary px-5 py-3 font-bold text-primary-fg shadow-hero disabled:bg-surface-muted disabled:text-ink-muted disabled:shadow-none"
              disabled={!submitEnabled}
              onClick={submitAnswer}
              type="button"
            >
              {isSubmitting ? "채점 중" : "정답 확인"}
            </button>
          </div>
        </section>
      </div>
    </main>
  );
}

type QuestionRendererProps = {
  draft: AnswerDraft;
  isLocked: boolean;
  onDraftChange: (draft: AnswerDraft) => void;
  question: PlayQuestion;
};

function QuestionRenderer({ draft, isLocked, onDraftChange, question }: QuestionRendererProps) {
  return (
    <div className="flex flex-1 flex-col">
      <div>
        <p className="text-xs font-bold text-ink-muted uppercase tracking-normal">
          {getQuestionKindLabel(question.kind)}
        </p>
        <h2 className="mt-2 text-2xl font-black leading-8">{question.prompt}</h2>
      </div>

      <div className="mt-auto space-y-4 pt-6">
        {question.kind === "ox" ? (
          <fieldset className="grid grid-cols-2 gap-3" aria-label="O 또는 X 선택">
            <OxButton
              disabled={isLocked}
              label="O"
              name={question.id}
              selected={draft === true}
              tone="yes"
              onClick={() => onDraftChange(true)}
            />
            <OxButton
              disabled={isLocked}
              label="X"
              name={question.id}
              selected={draft === false}
              tone="no"
              onClick={() => onDraftChange(false)}
            />
          </fieldset>
        ) : null}

        {question.kind === "multiple-choice" ? (
          <>
            {question.code ? (
              <CodeBlock code={question.code.source} languageLabel={question.code.language} />
            ) : null}
            <fieldset className="space-y-3" aria-label="사지선다 선택지">
              {question.options.map((option, index) => (
                <label
                  className={`flex min-h-14 w-full items-start gap-3 rounded-2xl border px-4 py-3 text-left text-sm font-semibold leading-6 transition ${
                    draft === option.id
                      ? "border-primary bg-surface shadow-card"
                      : "border-border bg-surface"
                  }`}
                  key={option.id}
                >
                  <input
                    checked={draft === option.id}
                    className="sr-only"
                    disabled={isLocked}
                    name={question.id}
                    onChange={() => onDraftChange(option.id)}
                    type="radio"
                  />
                  <span className="grid h-7 w-7 shrink-0 place-items-center rounded-chip bg-ink text-xs text-primary-fg">
                    {optionLabels[index]}
                  </span>
                  <span>{option.label}</span>
                </label>
              ))}
            </fieldset>
          </>
        ) : null}

        {question.kind === "keyword-blank" ? (
          <>
            {question.code ? (
              <CodeBlankBlock
                after={question.code.after}
                before={question.code.before}
                value={typeof draft === "string" ? draft : ""}
                onChange={(value) => onDraftChange(value)}
                disabled={isLocked}
                label={question.blankLabel}
              />
            ) : null}
            {!question.code ? (
              <label className="block">
                <span className="text-sm font-bold text-ink">{question.blankLabel}</span>
                <input
                  autoCapitalize="off"
                  autoComplete="off"
                  autoCorrect="off"
                  className="mt-2 min-h-12 w-full rounded-control border border-border bg-surface px-4 text-base font-semibold outline-none transition focus:border-primary disabled:text-ink-muted"
                  disabled={isLocked}
                  onChange={(event) => onDraftChange(event.target.value)}
                  placeholder="키워드를 입력하세요"
                  value={typeof draft === "string" ? draft : ""}
                />
              </label>
            ) : null}
          </>
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

function CodeBlankBlock({
  after,
  before,
  disabled,
  label,
  onChange,
  value,
}: {
  after: string;
  before: string;
  disabled: boolean;
  label: string;
  onChange: (value: string) => void;
  value: string;
}) {
  return (
    <div className="overflow-hidden rounded-control border border-border bg-ink text-primary-fg">
      <div className="border-border/20 border-b px-4 py-2 text-xs font-semibold text-primary-fg/70 uppercase">
        pseudo code
      </div>
      <div className="overflow-x-auto px-4 py-4 font-mono text-sm leading-6">
        <pre className="inline whitespace-pre-wrap">{before}</pre>
        <input
          aria-label={label}
          autoCapitalize="off"
          autoComplete="off"
          autoCorrect="off"
          className="mx-1 inline-block min-h-8 w-32 rounded-control border border-primary-fg/30 bg-ink px-2 font-mono text-primary-fg outline-none focus:border-primary-fg disabled:text-primary-fg/50"
          disabled={disabled}
          onChange={(event) => onChange(event.target.value)}
          value={value}
        />
        <pre className="inline whitespace-pre-wrap">{after}</pre>
      </div>
    </div>
  );
}

function getQuestionKindLabel(kind: PlayQuestion["kind"]) {
  if (kind === "ox") {
    return "OX";
  }

  if (kind === "multiple-choice") {
    return "사지선다";
  }

  return "키워드 빈칸";
}
