"use client";

import { useMemo, useState } from "react";
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
    <main className="min-h-screen bg-[linear-gradient(180deg,#eef4ff_0%,#f8fafc_45%,#edf2f7_100%)] px-4 py-5 text-slate-950 sm:px-6">
      <div className="mx-auto flex min-h-[calc(100vh-2.5rem)] w-full max-w-md flex-col gap-4">
        <header className="sticky top-4 z-10 rounded-[28px] border border-slate-200/90 bg-white/90 p-4 shadow-[0_18px_45px_rgba(15,23,42,0.10)] backdrop-blur">
          <div className="flex items-center justify-between gap-3">
            <a
              className="grid h-10 w-10 place-items-center rounded-full border border-slate-200 bg-slate-50 text-lg"
              aria-label="이전 문제로 돌아가기"
              href={currentIndex === 0 ? "/" : `/play?question=${currentIndex - 1}`}
            >
              ‹
            </a>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[0.72rem] font-semibold text-slate-500">
                {session.courseTitle}
              </p>
              <h1 className="truncate text-base font-bold">{session.unitTitle}</h1>
            </div>
          </div>
          <div className="mt-4">
            <div className="mb-2 flex items-center justify-between text-[0.72rem] font-semibold text-slate-500">
              <span>{currentIndex + 1}/5</span>
              <span>{getDifficultyLabel(question.difficulty)}</span>
            </div>
            <div
              aria-label="문제 진행률"
              aria-valuemax={100}
              aria-valuemin={0}
              aria-valuenow={progressPercent}
              className="h-2 rounded-full bg-slate-200"
              role="progressbar"
            >
              <div
                className="h-full rounded-full bg-slate-950 transition-all"
                style={{ width: `${progressPercent}%` }}
              />
            </div>
          </div>
          <p aria-live="polite" className="sr-only">
            {liveText}
          </p>
        </header>

        <section className="flex flex-1 flex-col rounded-[30px] border border-slate-200/90 bg-[#f7f9fc] p-5 shadow-[0_20px_55px_rgba(15,23,42,0.08)]">
          <QuestionRenderer
            draft={draft}
            isLocked={isSubmitting}
            onDraftChange={setDraft}
            question={question}
          />

          <div className="pt-4">
            <button
              className="min-h-12 w-full rounded-2xl bg-slate-950 px-5 py-3 font-bold text-white shadow-[0_14px_30px_rgba(15,23,42,0.22)] disabled:bg-slate-300 disabled:text-slate-500 disabled:shadow-none"
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
        <p className="text-[0.72rem] font-bold text-slate-500 uppercase tracking-normal">
          {getQuestionKindLabel(question.kind)}
        </p>
        <h2 className="mt-2 text-[1.45rem] font-black leading-8">{question.prompt}</h2>
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
                      ? "border-slate-950 bg-white shadow-[0_10px_24px_rgba(15,23,42,0.10)]"
                      : "border-slate-200 bg-white/70"
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
                  <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full bg-slate-950 text-xs text-white">
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
                <span className="text-sm font-bold text-slate-700">{question.blankLabel}</span>
                <input
                  autoCapitalize="off"
                  autoComplete="off"
                  autoCorrect="off"
                  className="mt-2 min-h-12 w-full rounded-2xl border border-slate-200 bg-white px-4 text-base font-semibold outline-none transition focus:border-slate-950 focus:ring-4 focus:ring-slate-200 disabled:text-slate-500"
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
      ? "border-emerald-500 bg-emerald-50 text-emerald-800"
      : "border-rose-500 bg-rose-50 text-rose-800";

  return (
    <label
      className={`flex min-h-28 items-center justify-center rounded-[26px] border bg-white text-5xl font-black transition ${
        selected ? selectedClassName : "border-slate-200 text-slate-300"
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
    <div className="overflow-hidden rounded-2xl border border-slate-200 bg-slate-950 text-slate-100">
      <div className="border-slate-800 border-b px-4 py-2 text-[0.68rem] font-semibold text-slate-400 uppercase">
        pseudo code
      </div>
      <div className="overflow-x-auto px-4 py-4 font-mono text-[0.82rem] leading-6">
        <pre className="inline whitespace-pre-wrap">{before}</pre>
        <input
          aria-label={label}
          autoCapitalize="off"
          autoComplete="off"
          autoCorrect="off"
          className="mx-1 inline-block min-h-8 w-32 rounded-lg border border-slate-600 bg-slate-900 px-2 font-mono text-slate-50 outline-none focus:border-white disabled:text-slate-400"
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
