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
    <main className="min-h-screen bg-[linear-gradient(180deg,#eef4ff_0%,#f8fafc_45%,#edf2f7_100%)] px-4 py-5 text-slate-950 sm:px-6">
      <div className="mx-auto flex min-h-[calc(100vh-2.5rem)] w-full max-w-md flex-col gap-4">
        <header className="rounded-[28px] border border-slate-200/90 bg-white/90 p-4 shadow-[0_18px_45px_rgba(15,23,42,0.10)]">
          <div className="flex items-center justify-between gap-3">
            <a
              aria-label="문제로 돌아가기"
              className="grid h-10 w-10 place-items-center rounded-full border border-slate-200 bg-slate-50 text-lg"
              href={`/play?question=${questionIndex}`}
            >
              ‹
            </a>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[0.72rem] font-semibold text-slate-500">
                {session.courseTitle}
              </p>
              <h1 className="truncate text-base font-bold">문제 해설</h1>
            </div>
            <span
              className={`rounded-full px-3 py-1.5 text-[0.72rem] font-bold ${
                correct ? "bg-emerald-100 text-emerald-900" : "bg-rose-100 text-rose-900"
              }`}
            >
              {correct ? "정답" : "오답"}
            </span>
          </div>
          <div className="mt-4">
            <div className="mb-2 flex items-center justify-between text-[0.72rem] font-semibold text-slate-500">
              <span>{questionIndex + 1}/5</span>
              <span>{getDifficultyLabel(question.difficulty)}</span>
            </div>
            <div
              aria-label="해설 진행률"
              aria-valuemax={100}
              aria-valuemin={0}
              aria-valuenow={getProgressPercent(questionIndex, total)}
              className="h-2 rounded-full bg-slate-200"
              role="progressbar"
            >
              <div
                className="h-full rounded-full bg-slate-950"
                style={{ width: `${getProgressPercent(questionIndex, total)}%` }}
              />
            </div>
          </div>
        </header>

        <section className="flex flex-1 flex-col rounded-[30px] border border-slate-200/90 bg-[#f7f9fc] p-5 shadow-[0_20px_55px_rgba(15,23,42,0.08)]">
          <div>
            <p className="text-[0.72rem] font-bold text-slate-500 uppercase tracking-normal">
              {getQuestionKindLabel(question)}
            </p>
            <h2 className="mt-2 text-[1.35rem] font-black leading-8">{question.prompt}</h2>
          </div>

          <div className="mt-5 rounded-2xl border border-slate-200 bg-white px-4 py-4">
            <p className="text-sm font-bold text-slate-900">핵심 정리</p>
            <ul className="mt-3 space-y-2">
              {question.insight.summary.map((line) => (
                <li className="flex gap-2 text-sm leading-6 text-slate-700" key={line}>
                  <span aria-hidden="true" className="mt-2 h-1.5 w-1.5 rounded-full bg-slate-950" />
                  <span>{line}</span>
                </li>
              ))}
            </ul>
          </div>

          <div className="mt-4 rounded-2xl border border-slate-200 bg-white px-4 py-4">
            <p className="text-sm font-bold text-slate-900">해설</p>
            <p className="mt-2 text-sm leading-6 text-slate-700">{question.explanation}</p>
          </div>

          <div className="mt-4 rounded-2xl border border-slate-200 bg-white px-4 py-4">
            <p className="text-sm font-bold text-slate-900">예시</p>
            <p className="mt-2 text-sm leading-6 text-slate-700">{question.insight.example}</p>
          </div>

          <div className="mt-4 flex items-center justify-between rounded-2xl border border-dashed border-slate-300 px-4 py-3 text-sm text-slate-600">
            <span>레퍼런스</span>
            <span className="font-semibold text-slate-900">{question.insight.referenceLabel}</span>
          </div>

          <div className="mt-auto pt-5">
            <a
              className="flex min-h-12 w-full items-center justify-center rounded-2xl bg-slate-950 px-5 py-3 font-bold text-white shadow-[0_14px_30px_rgba(15,23,42,0.22)]"
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
