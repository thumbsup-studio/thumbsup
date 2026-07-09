import { Progress } from "@/components/ui/progress";
import { getDifficultyLabel, getProgressPercent } from "@/features/play/play-logic";
import type { PlayQuestion, PlaySession } from "@/features/play/types";

type InsightPageProps = {
  correct: boolean;
  questionIndex: number;
  session: PlaySession;
};

export function InsightPage({ correct, questionIndex, session }: InsightPageProps) {
  const question = session.questions[questionIndex];
  const total = session.questions.length;
  const isLastQuestion = questionIndex === total - 1;
  const nextHref = isLastQuestion ? "/" : `/play?question=${questionIndex + 1}`;

  return (
    <main className="flex min-h-screen flex-col bg-bg px-4 py-5 text-ink sm:px-6">
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
              <span>{questionIndex + 1}/5</span>
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
          <div>
            <p className="text-xs font-bold text-ink-muted uppercase tracking-normal">
              {getQuestionKindLabel(question)}
            </p>
            <h2 className="mt-2 text-2xl font-black leading-8">{question.prompt}</h2>
          </div>

          <div className="mt-5 rounded-control border border-border bg-surface px-4 py-4">
            <p className="text-sm font-bold text-ink">핵심 정리</p>
            <ul className="mt-3 space-y-2">
              {question.insight.summary.map((line) => (
                <li className="flex gap-2 text-sm leading-6 text-ink-muted" key={line}>
                  <span aria-hidden="true" className="mt-2 h-1.5 w-1.5 rounded-chip bg-ink" />
                  <span>{line}</span>
                </li>
              ))}
            </ul>
          </div>

          <div className="mt-4 rounded-control border border-border bg-surface px-4 py-4">
            <p className="text-sm font-bold text-ink">해설</p>
            <p className="mt-2 text-sm leading-6 text-ink-muted">{question.explanation}</p>
          </div>

          <div className="mt-4 rounded-control border border-border bg-surface px-4 py-4">
            <p className="text-sm font-bold text-ink">예시</p>
            <p className="mt-2 text-sm leading-6 text-ink-muted">{question.insight.example}</p>
          </div>

          <div className="mt-4 flex items-center justify-between rounded-control border border-dashed border-border px-4 py-3 text-sm text-ink-muted">
            <span>레퍼런스</span>
            <span className="font-semibold text-ink">{question.insight.referenceLabel}</span>
          </div>

          <div className="mt-auto pt-5">
            <a
              className="flex min-h-12 w-full items-center justify-center rounded-control bg-primary px-5 py-3 font-bold text-primary-fg shadow-hero"
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
